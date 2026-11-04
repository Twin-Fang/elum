package com.chuseok22.elumserver.migration.application.service;

import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.common.infrastructure.properties.MigrationProperties;
import com.chuseok22.elumserver.migration.application.dto.response.SourceServerProbeView;
import com.chuseok22.elumserver.migration.application.dto.response.SourceServerProbeView.State;
import com.chuseok22.elumserver.migration.infrastructure.client.SourceServerStatusClient;
import com.chuseok22.elumserver.migration.infrastructure.client.SourceServerStatusClient.SourceServerHttpResponse;
import com.chuseok22.elumserver.systemconfig.core.ServerAddressPolicy;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 옛 서버 안내 상태 확인 (#1062): 공개 상태 조회 > 상태 코드 > 점검 여부·안내 주소 > 새 서버 주소 대조
 * 예외를 던지지 않음 (연결 실패·형식 다름도 화면 상태 하나)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SourceServerProbeService {

  private static final int HTTP_SUCCESS_MIN = 200;
  private static final int HTTP_SUCCESS_MAX = 299;

  private final MigrationProperties migrationProperties;
  private final SourceServerStatusClient sourceServerStatusClient;

  /// 옛 서버 1회 조회 > 화면 상태
  public SourceServerProbeView probe() {
    String sourceBaseUrl = migrationProperties.sourceBaseUrl();
    SourceServerHttpResponse response;
    try {
      response = sourceServerStatusClient.fetchAppStatus(sourceBaseUrl);
    } catch (RuntimeException e) {
      String failureReason = rootCauseNameOf(e);
      log.warn("[migration probe] source unreachable : error={}", failureReason);
      return failed(sourceBaseUrl, State.UNREACHABLE, null, failureReason);
    }
    if (response.statusCode() < HTTP_SUCCESS_MIN || response.statusCode() > HTTP_SUCCESS_MAX) {
      log.warn("[migration probe] source rejected : status={}", response.statusCode());
      return failed(sourceBaseUrl, State.HTTP_ERROR, response.statusCode(), "HTTP " + response.statusCode());
    }
    return toRespondedView(sourceBaseUrl, response);
  }

  /// 2xx 본문 > 점검 여부·안내 주소 (객체가 아니거나 maintenance 가 불리언이 아니면 형식 다름)
  private SourceServerProbeView toRespondedView(String sourceBaseUrl, SourceServerHttpResponse response) {
    JsonNode root;
    try {
      root = DefaultJsonMapper.SHARED.readTree(response.body());
    } catch (JsonProcessingException e) {
      log.warn("[migration probe] source body unreadable : status={} error={}",
        response.statusCode(), e.getClass().getSimpleName());
      return failed(sourceBaseUrl, State.UNEXPECTED_RESPONSE, response.statusCode(), e.getClass().getSimpleName());
    }
    JsonNode maintenance = root == null ? null : root.get("maintenance");
    if (maintenance == null || !maintenance.isBoolean()) {
      log.warn("[migration probe] source body unexpected : status={} reason=maintenance missing", response.statusCode());
      return failed(sourceBaseUrl, State.UNEXPECTED_RESPONSE, response.statusCode(), "maintenance 값 없음");
    }
    String announcedApiBaseUrl = announcedApiBaseUrlOf(root);
    return new SourceServerProbeView(
      sourceBaseUrl,
      ServerAddressPolicy.NEW_SERVER_BASE_URL,
      State.RESPONDED,
      response.statusCode(),
      null,
      maintenance.asBoolean(),
      announcedApiBaseUrl,
      ServerAddressPolicy.isNewServerAddress(announcedApiBaseUrl)
    );
  }

  /// server.apiBaseUrl (없거나 글이 아니면 null: 구버전 서버·이전 안내 전)
  private static String announcedApiBaseUrlOf(JsonNode root) {
    JsonNode apiBaseUrl = root.path("server").path("apiBaseUrl");
    return apiBaseUrl.isTextual() && !apiBaseUrl.asText().isBlank() ? apiBaseUrl.asText().trim() : null;
  }

  private static SourceServerProbeView failed(String sourceBaseUrl, State state, Integer httpStatus, String failureReason) {
    return new SourceServerProbeView(sourceBaseUrl, ServerAddressPolicy.NEW_SERVER_BASE_URL, state, httpStatus,
      failureReason, null, null, false);
  }

  /// 예외 > 가장 안쪽 원인 이름 (HttpTimeoutException, ConnectException, UnknownHostException 등)
  private static String rootCauseNameOf(Throwable throwable) {
    Throwable current = throwable;
    while (current.getCause() != null && current.getCause() != current) {
      current = current.getCause();
    }
    return current.getClass().getSimpleName();
  }
}
