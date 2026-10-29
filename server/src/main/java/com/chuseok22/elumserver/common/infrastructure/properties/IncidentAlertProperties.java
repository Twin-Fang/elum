package com.chuseok22.elumserver.common.infrastructure.properties;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 장애 알림 설정: Discord 웹훅 주소, 관리자 화면 기준 주소, 5xx 급증 기준, 쿨다운, AI 연속 실패 기준 (#648)
 * 웹훅 주소가 비거나 https 가 아니면 알림만 꺼짐 (서버 기동은 막지 않음)
 */
@ConfigurationProperties(prefix = "elum.incident-alert")
public record IncidentAlertProperties(
  String discordWebhookUrl,
  String adminBaseUrl,
  Integer serverErrorThreshold,
  Integer serverErrorWindowSeconds,
  Integer cooldownSeconds,
  Integer aiConsecutiveFailureThreshold
) {

  private static final String HTTPS_SCHEME_PREFIX = "https://";
  // 5xx 급증 기준: 창 안 건수
  private static final int DEFAULT_SERVER_ERROR_THRESHOLD = 10;
  // 5xx 급증 집계 창 (초, 5분)
  private static final int DEFAULT_SERVER_ERROR_WINDOW_SECONDS = 300;
  // 같은 알림 재발송 간격 (초, 30분)
  private static final int DEFAULT_COOLDOWN_SECONDS = 1800;
  // AI 제공자 연속 실패 기준 (회)
  private static final int DEFAULT_AI_CONSECUTIVE_FAILURE_THRESHOLD = 5;

  public IncidentAlertProperties {
    discordWebhookUrl = discordWebhookUrl == null ? "" : discordWebhookUrl.trim();
    adminBaseUrl = adminBaseUrl == null ? "" : withoutTrailingSlash(adminBaseUrl.trim());
    serverErrorThreshold = positiveOrDefault(serverErrorThreshold, DEFAULT_SERVER_ERROR_THRESHOLD);
    serverErrorWindowSeconds = positiveOrDefault(serverErrorWindowSeconds, DEFAULT_SERVER_ERROR_WINDOW_SECONDS);
    cooldownSeconds = positiveOrDefault(cooldownSeconds, DEFAULT_COOLDOWN_SECONDS);
    aiConsecutiveFailureThreshold =
      positiveOrDefault(aiConsecutiveFailureThreshold, DEFAULT_AI_CONSECUTIVE_FAILURE_THRESHOLD);
  }

  public boolean hasDiscordWebhookUrl() {
    return !discordWebhookUrl.isEmpty();
  }

  public boolean isDiscordWebhookUrlHttps() {
    return discordWebhookUrl.startsWith(HTTPS_SCHEME_PREFIX);
  }

  public Duration serverErrorWindow() {
    return Duration.ofSeconds(serverErrorWindowSeconds);
  }

  public Duration cooldown() {
    return Duration.ofSeconds(cooldownSeconds);
  }

  // 0·음수·미설정 > 기본값 (잘못 넣은 값 하나로 알림이 폭주하거나 꺼지지 않게)
  private static int positiveOrDefault(Integer value, int fallback) {
    return value == null || value <= 0 ? fallback : value;
  }

  private static String withoutTrailingSlash(String url) {
    return url.endsWith("/") ? url.substring(0, url.length() - 1) : url;
  }
}
