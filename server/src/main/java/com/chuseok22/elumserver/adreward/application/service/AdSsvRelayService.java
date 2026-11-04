package com.chuseok22.elumserver.adreward.application.service;

import com.chuseok22.elumserver.adreward.infrastructure.client.AdSsvRelayClient;
import com.chuseok22.elumserver.adreward.infrastructure.client.AdSsvRelayClient.RelayResponse;
import com.chuseok22.elumserver.common.infrastructure.constant.SecurityPaths;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import java.net.URI;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;

/**
 * 이전 잠금 중 광고 보상 콜백 전달 (#1053): 이미 전달됨·새 주소 없음 > 503, 그 밖은 새 서버로 원문 쿼리 그대로
 * AdMob 콘솔 콜백 주소를 바꾸기 전까지 들어오는 보상을 잃지 않게 한다. 503 이면 Google 이 다시 보낸다
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AdSsvRelayService {

  private static final String UNAVAILABLE_BODY = "unavailable";
  private static final String QUERY_DELIMITER = "?";

  private final MigrationLock migrationLock;
  private final AdSsvRelayClient adSsvRelayClient;

  public ResponseEntity<String> relay(String rawQuery, boolean isAlreadyRelayed) {
    if (isAlreadyRelayed) {
      log.warn("[ad ssv relay] rejected 503 : already relayed (both servers locked?)");
      return unavailable();
    }
    Optional<String> newServerBaseUrl = migrationLock.newServerBaseUrl();
    if (newServerBaseUrl.isEmpty()) {
      log.warn("[ad ssv relay] rejected 503 : no new server base url");
      return unavailable();
    }
    // 주소 조립 실패(쿼리에 허용되지 않는 글자)·연결 실패 모두 503
    try {
      URI target = URI.create(newServerBaseUrl.get() + SecurityPaths.API_ADS_SSV + QUERY_DELIMITER
        + (rawQuery == null ? "" : rawQuery));
      RelayResponse response = adSsvRelayClient.forward(target);
      log.info("[ad ssv relay] forwarded : status={}", response.status());
      return ResponseEntity.status(response.status()).body(response.body());
    } catch (RuntimeException e) {
      log.warn("[ad ssv relay] failed 503 : {}", e.getClass().getSimpleName());
      return unavailable();
    }
  }

  private static ResponseEntity<String> unavailable() {
    return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(UNAVAILABLE_BODY);
  }
}
