package com.chuseok22.elumserver.auth.application.service;

import com.chuseok22.elumserver.auth.infrastructure.entity.RefreshToken;
import com.chuseok22.elumserver.auth.infrastructure.repository.RefreshTokenRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkAccessValidator;
import com.chuseok22.elumserver.common.infrastructure.properties.JwtProperties;
import com.chuseok22.elumserver.link.core.ElumiDeviceId;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.HexFormat;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 리프레시 토큰 발급·회전·폐기.
 *
 * <p>액세스 토큰은 1일, 리프레시는 6개월이다. 앱은 액세스가 만료되면 조용히 갱신하므로
 * 사용자는 로그아웃을 겪지 않는다. 인스타그램에서 로그인 상태가 계속 유지되는 것과 같은 방식이다.
 *
 * <p><b>왜 JWT가 아닌가</b> — 리프레시는 서버가 언제든 끊을 수 있어야 한다. JWT는
 * 서명만 맞으면 유효해서 끊을 방법이 없다. 그래서 무작위 문자열을 발급하고 DB에
 * 해시만 남긴다. 해시로 두면 DB가 통째로 새도 토큰 자체는 새지 않는다.
 *
 * <p><b>회전과 재사용 감지</b> — 갱신할 때마다 새 토큰을 주고 쓴 토큰은 즉시 끊는다.
 * 이미 끊긴 토큰이 다시 오면 누군가 복사본을 들고 있다는 뜻이므로 그 보호자의 보호자 휴대폰
 * 세션을 끊는다(이룸이 휴대폰은 남긴다). 이룸이 휴대폰 토큰이면 그 휴대폰만 끊는다 (다중 보호자 E34).
 * 정상 사용자는 다시 로그인하면 되지만, 회전이 없으면 탈취를 영영 모른다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RefreshTokenService {

  private static final SecureRandom RANDOM = new SecureRandom();
  private static final int TOKEN_BYTES = 48;
  /// 로그아웃이 회전 체인을 따라가는 최대 길이. 꼬인 체인에서 무한히 돌지 않게 한다.
  private static final int MAX_CHAIN_HOPS = 500;

  private final RefreshTokenRepository refreshTokenRepository;
  private final RefreshTokenRevoker refreshTokenRevoker;
  private final JwtProperties jwtProperties;
  private final LinkAccessValidator linkAccessValidator;

  /**
   * 새 리프레시 토큰을 발급한다.
   *
   * @return 클라이언트에 내려줄 <b>원문</b>. 서버는 이 값을 다시 볼 수 없다(해시만 저장).
   */
  @Transactional
  public String issue(String memberId, String deviceId) {
    return save(memberId, deviceId, null).rawToken();
  }

  /**
   * 리프레시 토큰을 검증하고 새 토큰으로 교체한다.
   *
   * @return 계정 ID와 새 리프레시 토큰 원문
   */
  @Transactional
  public RotationResult rotate(String rawToken, String deviceId) {
    if (rawToken == null || rawToken.isBlank()) {
      throw new CustomException(ErrorCode.REFRESH_TOKEN_INVALID);
    }

    RefreshToken current = refreshTokenRepository.findByTokenHash(hash(rawToken))
      .orElseThrow(() -> new CustomException(ErrorCode.REFRESH_TOKEN_INVALID));

    LocalDateTime now = LocalDateTime.now();

    // 이룸이 휴대폰 세션인지는 요청 헤더가 아니라 저장된 기기 값으로 가린다 (이슈 #359).
    String linkId = ElumiDeviceId.linkIdOf(current.getDeviceId());

    // 연결이 끊긴 이룸이 휴대폰이면 그 기기 세션만 끊고 거절한다.
    // 재사용 감지보다 먼저 본다 — 보호자가 연결을 끊으면 그 기기 토큰은 이미 폐기돼 있어,
    // 뒤에 두면 끊긴 휴대폰의 갱신 한 번이 재사용으로 잡혀 보호자 세션까지 전부 끊긴다.
    // 폐기는 별도 트랜잭션이다. 같은 트랜잭션이면 아래 예외에 롤백된다.
    if (linkId != null && !linkAccessValidator.isLinkActive(linkId)) {
      int revoked = refreshTokenRevoker.revokeDeviceInNewTransaction(
        current.getMemberId(), current.getDeviceId(), now);
      log.info("끊긴 연결의 이룸이 휴대폰 갱신을 거절했습니다. memberId={}, deviceId={}, 끊은 세션={}",
        current.getMemberId(), current.getDeviceId(), revoked);
      throw new CustomException(ErrorCode.REFRESH_TOKEN_INVALID);
    }

    // 이미 끊긴 토큰이 다시 왔다 = 복사본이 돌아다닌다.
    //
    // 폐기는 **별도 트랜잭션**에서 해야 한다. 같은 트랜잭션에서 하면 바로 아래
    // 예외가 롤백을 일으켜 폐기가 되돌아간다 — 감지만 하고 세션은 살아 있게 된다.
    // 보호자 토큰이면 보호자 휴대폰들을, 이룸이 휴대폰 토큰이면 그 휴대폰만 끊는다 (다중 보호자 E34).
    // 둘은 따로 믿는 대상이라 한쪽이 새었다고 다른 쪽을 끊지 않는다.
    if (current.getRevokedAt() != null) {
      int revoked = linkId != null
        ? refreshTokenRevoker.revokeDeviceInNewTransaction(current.getMemberId(), current.getDeviceId(), now)
        : refreshTokenRevoker.revokeGuardianSessionsInNewTransaction(current.getMemberId(), now);
      log.warn("리프레시 토큰이 재사용되어 세션을 끊었습니다. memberId={}, 이룸이 휴대폰={}, 끊은 수={}",
        current.getMemberId(), linkId != null, revoked);
      throw new CustomException(ErrorCode.REFRESH_TOKEN_REUSED);
    }

    if (!current.isUsable(now)) {
      throw new CustomException(ErrorCode.REFRESH_TOKEN_INVALID);
    }

    // 기기 정보는 이번 갱신 값으로 이어 준다. 앱 재설치로 기기 ID가 바뀌어도 세션은 유지된다.
    // 단 이룸이 휴대폰 값은 헤더로 바꾸지 못한다 — elumi- 가 떨어지면 다음 갱신부터 보호자
    // 토큰이 나오고, 보호자가 연결을 끊어도 이 세션이 짚히지 않는다 (이슈 #359).
    boolean followHeader = linkId == null && deviceId != null && !deviceId.isBlank();
    String nextDeviceId = followHeader ? deviceId : current.getDeviceId();
    IssuedToken next = save(current.getMemberId(), nextDeviceId, current.getId());

    current.setRevokedAt(now);
    current.setLastUsedAt(now);
    current.setReplacedById(next.entity().getId());

    return new RotationResult(current.getMemberId(), next.rawToken(), linkId);
  }

  /**
   * 로그아웃. <b>그 기기의 세션만</b> 끊는다 (다중 보호자 E33).
   *
   * <p>예전에는 넘어온 토큰의 계정 세션을 전부 끊었다 — 보호자 휴대폰 한 대에서 로그아웃하면 그 보호자가
   * 붙인 이룸이 휴대폰과 다른 휴대폰까지 끊겼다(2026-09-23 실측).
   *
   * <p>앱은 기기 값을 보내지 않아 {@code device_id} 로는 기기를 가릴 수 없다(보호자 세션은 대개 NULL).
   * 그래서 넘어온 토큰에서 시작해 회전으로 이어진 뒤 토큰들을 따라가며 끊는다 — 그 줄기가 곧 그 기기의
   * 세션이다. 앱이 옛 토큰을 보내도 살아 있는 끝까지 닿는다.
   */
  @Transactional
  public void revokeSession(String rawToken) {
    if (rawToken == null || rawToken.isBlank()) {
      return;
    }
    refreshTokenRepository.findByTokenHash(hash(rawToken)).ifPresent(start -> {
      LocalDateTime now = LocalDateTime.now();
      RefreshToken cursor = start;
      // 하루 한 번 갱신해도 반년이면 180 개다. 체인이 꼬여 돌아도 여기서 멈춘다.
      for (int hops = 0; cursor != null && hops < MAX_CHAIN_HOPS; hops++) {
        if (cursor.getRevokedAt() == null) {
          cursor.setRevokedAt(now);
        }
        String nextId = cursor.getReplacedById();
        cursor = nextId == null ? null : refreshTokenRepository.findById(nextId).orElse(null);
      }
    });
  }

  /** 회원 탈퇴·강제 로그아웃용. */
  @Transactional
  public void revokeAll(String memberId) {
    refreshTokenRepository.revokeAllByMemberId(memberId, LocalDateTime.now());
  }

  private IssuedToken save(String memberId, String deviceId, String previousId) {
    byte[] bytes = new byte[TOKEN_BYTES];
    RANDOM.nextBytes(bytes);
    String rawToken = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);

    RefreshToken token = new RefreshToken();
    token.setMemberId(memberId);
    token.setTokenHash(hash(rawToken));
    token.setDeviceId(deviceId);
    token.setExpiresAt(LocalDateTime.now().plusNanos(jwtProperties.refreshExpMillis() * 1_000_000L));
    if (previousId != null) {
      token.setLastUsedAt(LocalDateTime.now());
    }

    return new IssuedToken(refreshTokenRepository.save(token), rawToken);
  }

  private String hash(String rawToken) {
    try {
      MessageDigest digest = MessageDigest.getInstance("SHA-256");
      return HexFormat.of().formatHex(digest.digest(rawToken.getBytes(StandardCharsets.UTF_8)));
    } catch (NoSuchAlgorithmException e) {
      // SHA-256은 JDK 표준이라 실제로는 발생하지 않는다.
      throw new IllegalStateException("SHA-256을 사용할 수 없습니다", e);
    }
  }

  /**
   * @param linkId 이룸이 휴대폰 세션이면 그 연결 ID, 보호자 세션이면 null.
   *               새 액세스 토큰의 역할을 이 값으로 정한다.
   */
  public record RotationResult(String memberId, String refreshToken, String linkId) {

  }

  private record IssuedToken(RefreshToken entity, String rawToken) {

  }
}
