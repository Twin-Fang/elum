package com.chuseok22.elumserver.license.infrastructure.store.apple;

import com.apple.itunes.storekit.model.Environment;
import com.apple.itunes.storekit.model.JWSRenewalInfoDecodedPayload;
import com.apple.itunes.storekit.model.JWSTransactionDecodedPayload;
import com.apple.itunes.storekit.model.ResponseBodyV2DecodedPayload;
import com.apple.itunes.storekit.verification.SignedDataVerifier;
import com.apple.itunes.storekit.verification.VerificationException;
import com.apple.itunes.storekit.verification.VerificationStatus;
import com.chuseok22.elumserver.license.application.service.store.StoreTemporarilyUnavailableException;
import com.chuseok22.elumserver.license.application.service.store.StoreVerifyRejectedException;
import com.chuseok22.elumserver.license.core.StoreEnvironment;
import com.chuseok22.elumserver.license.core.StoreVerifyRejectReason;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

/**
 * App Store 서명 데이터(JWS) 검증: x5c 체인 > Apple 루트 인증서, ES256 서명, 번들 ID, 환경 (Apple 공식 라이브러리)
 * 환경 2개: Production 먼저, Sandbox 는 허용할 때만 통과. Xcode·로컬 테스트 환경은 서명 검증을 건너뛰므로 만들지 않음
 * 온라인 인증서 폐기 확인(OCSP)은 끔 (Apple 장애가 결제 장애가 되지 않게)
 */
@Slf4j
@Component
public class AppleSignedDataVerifier {

  /// 운영 루트 인증서: Apple Root CA - G3 (SHA-256 63:34:3A:BF:…:3E:91:79)
  static final String APPLE_ROOT_CERTIFICATE_PATH = "store/apple/AppleRootCA-G3.cer";
  private static final boolean IS_ONLINE_CHECK_ENABLED = false;

  private final List<byte[]> rootCertificates;
  // (환경, 번들 ID, 앱 ID) > 검증기. 설정이 바뀌면 새 키로 다시 만든다
  private final Map<VerifierKey, SignedDataVerifier> verifiers = new ConcurrentHashMap<>();

  @Autowired
  public AppleSignedDataVerifier() {
    this(List.of(readClasspath(APPLE_ROOT_CERTIFICATE_PATH)));
  }

  /// 시험용: 자체 서명 루트를 넣는다 (실제 Apple 호출 없이 체인·서명 검증 시험)
  public AppleSignedDataVerifier(List<byte[]> rootCertificates) {
    this.rootCertificates = List.copyOf(rootCertificates);
  }

  public Verified<JWSTransactionDecodedPayload> verifyTransaction(String jws, AppleVerifyContext context) {
    return verifyAcrossEnvironments(context, verifier -> verifier.verifyAndDecodeTransaction(jws));
  }

  public JWSRenewalInfoDecodedPayload verifyRenewalInfo(String jws, StoreEnvironment environment, AppleVerifyContext context) {
    return verifyIn(environment, context, verifier -> verifier.verifyAndDecodeRenewalInfo(jws));
  }

  /// 같은 알림 안의 거래·갱신 정보는 알림과 같은 환경으로만 검증
  public JWSTransactionDecodedPayload verifyTransactionIn(String jws, StoreEnvironment environment, AppleVerifyContext context) {
    return verifyIn(environment, context, verifier -> verifier.verifyAndDecodeTransaction(jws));
  }

  public Verified<ResponseBodyV2DecodedPayload> verifyNotification(String signedPayload, AppleVerifyContext context) {
    return verifyAcrossEnvironments(context, verifier -> verifier.verifyAndDecodeNotification(signedPayload));
  }

  /**
   * Production 검증 > 환경·앱 ID 불일치면 Sandbox 검증기로 완전 재검증 > Sandbox 허용 확인
   * Sandbox 알림은 앱 ID 가 비어 와서 Production 검증기가 환경보다 앱 ID 불일치를 먼저 던짐 (#1187)
   */
  private <T> Verified<T> verifyAcrossEnvironments(AppleVerifyContext context, VerifyCall<T> call) {
    VerificationException productionFailure;
    try {
      return new Verified<>(call.verify(verifierOf(StoreEnvironment.PRODUCTION, context)), StoreEnvironment.PRODUCTION);
    } catch (VerificationException e) {
      if (!isRetryableInSandbox(e.getStatus())) {
        throw toLoggedRejection(StoreEnvironment.PRODUCTION, e);
      }
      productionFailure = e;
    } catch (StoreVerifyRejectedException | StoreTemporarilyUnavailableException e) {
      throw e;
    } catch (RuntimeException e) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.MALFORMED, e.getClass().getSimpleName());
    }
    T sandboxPayload = verifyInSandboxAfter(productionFailure, context, call);
    // 서명 검증을 통과한 Sandbox 값이어도 허용이 꺼져 있으면 거부 (알림은 200 무시로 처리)
    if (!context.isSandboxAllowed()) {
      log.info("[subscription apple] rejected : environment=SANDBOX, status=VERIFIED, reason={}",
        StoreVerifyRejectReason.ENVIRONMENT_NOT_ALLOWED);
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.ENVIRONMENT_NOT_ALLOWED, "sandbox");
    }
    log.info("[subscription apple] verified : environment=SANDBOX, productionStatus={}", productionFailure.getStatus());
    return new Verified<>(sandboxPayload, StoreEnvironment.SANDBOX);
  }

  // Sandbox 검증기 재검증 (체인·서명·번들·환경=Sandbox)
  private <T> T verifyInSandboxAfter(VerificationException productionFailure, AppleVerifyContext context, VerifyCall<T> call) {
    try {
      return call.verify(verifierOf(StoreEnvironment.SANDBOX, context));
    } catch (VerificationException e) {
      // Sandbox 도 환경 불일치면 Production 쪽 사유가 진짜 원인 (다른 앱 ID 의 Production 알림, Xcode 환경)
      if (e.getStatus() == VerificationStatus.INVALID_ENVIRONMENT) {
        throw toLoggedRejection(StoreEnvironment.PRODUCTION, productionFailure);
      }
      throw toLoggedRejection(StoreEnvironment.SANDBOX, e);
    } catch (StoreVerifyRejectedException | StoreTemporarilyUnavailableException e) {
      throw e;
    } catch (RuntimeException e) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.MALFORMED, e.getClass().getSimpleName());
    }
  }

  // 환경 불일치 + 앱 ID 불일치(Sandbox 알림은 앱 ID 없음). 번들 불일치도 같은 상태라 Sandbox 에서 다시 걸러짐
  private static boolean isRetryableInSandbox(VerificationStatus status) {
    return status == VerificationStatus.INVALID_ENVIRONMENT || status == VerificationStatus.INVALID_APP_IDENTIFIER;
  }

  // 검증 실패 > 거부 사유 변환 + 마지막으로 시도한 환경·상태 기록
  private static RuntimeException toLoggedRejection(StoreEnvironment lastTriedEnvironment, VerificationException e) {
    RuntimeException rejection = toRejection(e);
    String reason = rejection instanceof StoreVerifyRejectedException rejected ? rejected.getReason().name() : "RETRY_LATER";
    log.warn("[subscription apple] verify failed : environment={}, status={}, reason={}", lastTriedEnvironment, e.getStatus(), reason);
    return rejection;
  }

  private <T> T verifyIn(StoreEnvironment environment, AppleVerifyContext context, VerifyCall<T> call) {
    if (environment == StoreEnvironment.SANDBOX && !context.isSandboxAllowed()) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.ENVIRONMENT_NOT_ALLOWED, "sandbox");
    }
    try {
      return call.verify(verifierOf(environment, context));
    } catch (VerificationException e) {
      throw toLoggedRejection(environment, e);
    } catch (RuntimeException e) {
      throw new StoreVerifyRejectedException(StoreVerifyRejectReason.MALFORMED, e.getClass().getSimpleName());
    }
  }

  private SignedDataVerifier verifierOf(StoreEnvironment environment, AppleVerifyContext context) {
    // Production 은 앱 ID 가 있어야 알림의 앱을 확인할 수 있다 (라이브러리 규칙)
    if (environment == StoreEnvironment.PRODUCTION && context.appAppleId() == null) {
      throw new StoreTemporarilyUnavailableException("apple app id not configured");
    }
    VerifierKey key = new VerifierKey(environment, context.bundleId(), context.appAppleId());
    return verifiers.computeIfAbsent(key, this::createVerifier);
  }

  private SignedDataVerifier createVerifier(VerifierKey key) {
    Set<InputStream> roots = rootCertificates.stream()
      .map(ByteArrayInputStream::new)
      .collect(Collectors.toSet());
    Environment environment = key.environment() == StoreEnvironment.PRODUCTION ? Environment.PRODUCTION : Environment.SANDBOX;
    return new SignedDataVerifier(roots, key.bundleId(), key.appAppleId(), environment, IS_ONLINE_CHECK_ENABLED);
  }

  // 검증 상태 > 거부 사유 (재시도 가능한 실패만 "확인 중")
  private static RuntimeException toRejection(VerificationException e) {
    VerificationStatus status = e.getStatus();
    if (status == VerificationStatus.RETRYABLE_VERIFICATION_FAILURE) {
      return new StoreTemporarilyUnavailableException("apple verification retryable", e);
    }
    StoreVerifyRejectReason reason = switch (status) {
      case INVALID_APP_IDENTIFIER -> StoreVerifyRejectReason.APP_MISMATCH;
      case INVALID_ENVIRONMENT -> StoreVerifyRejectReason.ENVIRONMENT_NOT_ALLOWED;
      default -> StoreVerifyRejectReason.SIGNATURE_INVALID;
    };
    return new StoreVerifyRejectedException(reason, status.name());
  }

  private static byte[] readClasspath(String path) {
    try (InputStream input = new ClassPathResource(path).getInputStream()) {
      return input.readAllBytes();
    } catch (IOException e) {
      throw new UncheckedIOException("apple root certificate missing: " + path, e);
    }
  }

  /// 검증 통과 값 + 그 값이 속한 환경
  public record Verified<T>(T payload, StoreEnvironment environment) {

  }

  /**
   * 검증 기준: 번들 ID, 앱 ID(숫자, Production 알림 확인용), Sandbox 허용 여부
   */
  public record AppleVerifyContext(String bundleId, Long appAppleId, boolean isSandboxAllowed) {

  }

  private record VerifierKey(StoreEnvironment environment, String bundleId, Long appAppleId) {

  }

  @FunctionalInterface
  private interface VerifyCall<T> {

    T verify(SignedDataVerifier verifier) throws VerificationException;
  }
}
