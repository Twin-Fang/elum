package com.chuseok22.elumserver.license.infrastructure.store.apple;

import com.chuseok22.elumserver.license.application.service.store.StoreSubscriptionSettings.AppleServerApiCredentials;
import com.chuseok22.elumserver.license.core.StoreEnvironment;
import java.util.Optional;

/**
 * App Store Server API 로 구독 최신 상태 조회 (서명된 거래·갱신 정보 원문을 돌려받아 다시 검증)
 * 시간 초과·5xx·인증 실패는 StoreTemporarilyUnavailableException, 없는 거래는 빈 값
 */
public interface AppleSubscriptionStatusClient {

  Optional<SignedSubscriptionStatus> fetchLatest(
    String originalTransactionId, StoreEnvironment environment, String bundleId, AppleServerApiCredentials credentials
  );

  /// 한 구독의 마지막 거래 JWS + 갱신 정보 JWS (갱신 정보는 없을 수 있음)
  record SignedSubscriptionStatus(String signedTransactionInfo, String signedRenewalInfo) {

  }
}
