package com.chuseok22.elumserver.license.infrastructure.store.apple;

import com.apple.itunes.storekit.client.APIException;
import com.apple.itunes.storekit.client.AppStoreServerAPIClient;
import com.apple.itunes.storekit.model.Environment;
import com.apple.itunes.storekit.model.LastTransactionsItem;
import com.apple.itunes.storekit.model.Status;
import com.apple.itunes.storekit.model.StatusResponse;
import com.apple.itunes.storekit.model.SubscriptionGroupIdentifierItem;
import com.chuseok22.elumserver.license.application.service.store.StoreLogValues;
import com.chuseok22.elumserver.license.application.service.store.StoreSubscriptionSettings.AppleServerApiCredentials;
import com.chuseok22.elumserver.license.application.service.store.StoreTemporarilyUnavailableException;
import com.chuseok22.elumserver.license.core.StoreEnvironment;
import java.io.IOException;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * App Store Server API 구독 상태 조회 (Get All Subscription Statuses, Apple 공식 라이브러리)
 * 404 > 없는 거래(빈 값), 그 외 실패 > 확인 중. 클라이언트는 (환경, 인증값, 번들) 별로 1개만 만들어 재사용
 */
@Slf4j
@Component
public class StoreKitAppleSubscriptionStatusClient implements AppleSubscriptionStatusClient {

  private static final int HTTP_NOT_FOUND = 404;
  private static final String PEM_HEADER = "-----BEGIN PRIVATE KEY-----";
  private static final String PEM_FOOTER = "-----END PRIVATE KEY-----";

  private final Map<ClientKey, AppStoreServerAPIClient> clients = new ConcurrentHashMap<>();

  @Override
  public Optional<SignedSubscriptionStatus> fetchLatest(
    String originalTransactionId, StoreEnvironment environment, String bundleId, AppleServerApiCredentials credentials
  ) {
    StatusResponse response;
    try {
      response = clientOf(environment, bundleId, credentials).getAllSubscriptionStatuses(originalTransactionId, new Status[0]);
    } catch (APIException e) {
      if (e.getHttpStatusCode() == HTTP_NOT_FOUND) {
        return Optional.empty();
      }
      log.warn("[subscription verify] apple api failed : status={}, apiError={}, transaction={}",
        e.getHttpStatusCode(), e.getRawApiError(), StoreLogValues.mask(originalTransactionId));
      throw new StoreTemporarilyUnavailableException("apple api status " + e.getHttpStatusCode(), e);
    } catch (IOException e) {
      throw new StoreTemporarilyUnavailableException("apple api io failure", e);
    } catch (RuntimeException e) {
      // 개인 키 형식 오류 등 (설정 문제라 재시도해도 같지만, 구매를 버리지 않도록 확인 중으로)
      log.error("[subscription verify] apple api client error : {}", e.getClass().getSimpleName());
      throw new StoreTemporarilyUnavailableException("apple api client error", e);
    }
    return findTransaction(response, originalTransactionId);
  }

  // 구독 그룹 > 마지막 거래 목록에서 같은 originalTransactionId 찾기
  private static Optional<SignedSubscriptionStatus> findTransaction(StatusResponse response, String originalTransactionId) {
    if (response == null || response.getData() == null) {
      return Optional.empty();
    }
    for (SubscriptionGroupIdentifierItem group : response.getData()) {
      List<LastTransactionsItem> lastTransactions = group.getLastTransactions();
      if (lastTransactions == null) {
        continue;
      }
      for (LastTransactionsItem item : lastTransactions) {
        if (Objects.equals(originalTransactionId, item.getOriginalTransactionId()) && item.getSignedTransactionInfo() != null) {
          return Optional.of(new SignedSubscriptionStatus(item.getSignedTransactionInfo(), item.getSignedRenewalInfo()));
        }
      }
    }
    return Optional.empty();
  }

  private AppStoreServerAPIClient clientOf(StoreEnvironment environment, String bundleId, AppleServerApiCredentials credentials) {
    String privateKeyPem = normalizePrivateKeyPem(credentials.privateKeyPem());
    ClientKey key = new ClientKey(environment, bundleId, credentials.issuerId(), credentials.keyId(), privateKeyPem.hashCode());
    return clients.computeIfAbsent(key, ignored -> new AppStoreServerAPIClient(
      privateKeyPem, credentials.keyId(), credentials.issuerId(), bundleId,
      environment == StoreEnvironment.PRODUCTION ? Environment.PRODUCTION : Environment.SANDBOX));
  }

  /// .p8 붙여넣기 정리: 머리·꼬리 줄과 모든 공백을 지운 뒤 표준 PEM 으로 (관리자 입력칸이 줄바꿈을 지움)
  static String normalizePrivateKeyPem(String rawPem) {
    String body = rawPem.replace(PEM_HEADER, "").replace(PEM_FOOTER, "").replaceAll("\\s+", "");
    return PEM_HEADER + "\n" + body + "\n" + PEM_FOOTER;
  }

  private record ClientKey(StoreEnvironment environment, String bundleId, String issuerId, String keyId, int privateKeyHash) {

  }
}
