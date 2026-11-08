package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardAttention;
import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerAttentionResponse;
import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerAttentionSource;
import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerIntegrationPanel;
import com.chuseok22.elumserver.common.infrastructure.logging.InstanceInfo;
import com.chuseok22.elumserver.common.infrastructure.properties.ControlTowerAttentionProperties;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.talk.application.service.TalkAdminService;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Service;

/**
 * 관제소 확인할 일 연동 (#1229): 켜짐 확인, 스냅샷 집계, 마지막 수집 시각, 관리자 화면 칸
 * 집계는 대시보드 확인할 일(60초 캐시) + 이야기 신고 수(건수 조회 1번)만 씀 (요청마다 무거운 조회 없음)
 * 마지막 수집 시각은 인스턴스 메모리 (Blue/Green 전환·재시작 시 비워짐)
 */
@Slf4j
@Service
public class ControlTowerAttentionService {

  static final String SOURCE_APP_NAME = "elum-server";
  // source.environment 값 2개: 운영 프로필(prod) > production, 그 외 > development (production 이 아니면 관제소 알림 없음)
  static final String ENVIRONMENT_PRODUCTION = "production";
  static final String ENVIRONMENT_DEVELOPMENT = "development";
  private static final String PRODUCTION_PROFILE = "prod";
  // 미리보기 실패 시 관리자 화면 문구
  private static final String PREVIEW_FAILURE_MESSAGE = "지금 집계를 만들지 못했어요. 서버 로그를 확인하세요.";

  private final AdminDashboardService adminDashboardService;
  private final TalkAdminService talkAdminService;
  private final SystemConfigService systemConfigService;
  private final ControlTowerAttentionProperties properties;
  private final ControlTowerTokenVerifier tokenVerifier;
  private final Environment environment;
  private final InstanceInfo instanceInfo;
  private final Clock clock;

  private volatile Instant lastCollectedAt;

  @Autowired
  public ControlTowerAttentionService(
    AdminDashboardService adminDashboardService,
    TalkAdminService talkAdminService,
    SystemConfigService systemConfigService,
    ControlTowerAttentionProperties properties,
    ControlTowerTokenVerifier tokenVerifier,
    Environment environment,
    InstanceInfo instanceInfo
  ) {
    this(adminDashboardService, talkAdminService, systemConfigService, properties, tokenVerifier, environment,
      instanceInfo, Clock.systemUTC());
  }

  /// 시험에서 시계를 바꿔 끼우려고 열어 둔 생성자
  ControlTowerAttentionService(
    AdminDashboardService adminDashboardService,
    TalkAdminService talkAdminService,
    SystemConfigService systemConfigService,
    ControlTowerAttentionProperties properties,
    ControlTowerTokenVerifier tokenVerifier,
    Environment environment,
    InstanceInfo instanceInfo,
    Clock clock
  ) {
    this.adminDashboardService = adminDashboardService;
    this.talkAdminService = talkAdminService;
    this.systemConfigService = systemConfigService;
    this.properties = properties;
    this.tokenVerifier = tokenVerifier;
    this.environment = environment;
    this.instanceInfo = instanceInfo;
    this.clock = clock;
  }

  /// 관리자 시스템 설정 CONTROL_TOWER_ATTENTION_ENABLED (꺼짐이면 수집 요청 404)
  public boolean isEnabled() {
    return systemConfigService.getBoolean(ConfigKey.CONTROL_TOWER_ATTENTION_ENABLED);
  }

  public boolean isTokenAccepted(String presentedToken) {
    return tokenVerifier.isAccepted(presentedToken);
  }

  /// 토큰 검사를 통과한 요청 시각 기록 (관리자 화면 "마지막 관제소 수집")
  public void recordCollected() {
    lastCollectedAt = clock.instant();
  }

  /** 스냅샷: 대시보드 확인할 일 + 이야기 신고 수 > 항목 6개 + 출처 + 만든 시각(UTC) */
  public ControlTowerAttentionResponse buildSnapshot() {
    AdminDashboardAttention attention = adminDashboardService.summary().attention();
    long unresolvedTalkReportCount = talkAdminService.countUnresolvedReports();
    String adminBaseUrl = properties.hasHttpsAdminBaseUrl() ? properties.adminBaseUrl() : "";
    ControlTowerAttentionSource source = new ControlTowerAttentionSource(
      SOURCE_APP_NAME, instanceInfo.version(), environmentName(), adminBaseUrl.isEmpty() ? null : adminBaseUrl);
    return ControlTowerAttentionResponse.of(source, generatedAtText(),
      ControlTowerAttentionItemFactory.itemsOf(attention, unresolvedTalkReportCount, adminBaseUrl));
  }

  /** 관리자 화면 칸: 켜짐, 토큰 설정 여부, 마지막 수집 시각(서울), 미리보기 (집계 실패해도 화면은 그림) */
  public ControlTowerIntegrationPanel buildPanel() {
    ControlTowerAttentionResponse preview = null;
    String previewFailureMessage = null;
    try {
      preview = buildSnapshot();
    } catch (RuntimeException e) {
      log.warn("[control attention] preview failed : {}", e.getClass().getSimpleName());
      previewFailureMessage = PREVIEW_FAILURE_MESSAGE;
    }
    return new ControlTowerIntegrationPanel(isEnabled(), tokenVerifier.isTokenConfigured(),
      properties.hasHttpsAdminBaseUrl(), toAdminLocalTime(lastCollectedAt), preview, previewFailureMessage);
  }

  private String environmentName() {
    return environment.matchesProfiles(PRODUCTION_PROFILE) ? ENVIRONMENT_PRODUCTION : ENVIRONMENT_DEVELOPMENT;
  }

  // 관제소 규격: UTC ISO 8601 (예 2026-11-08T12:00:00.123Z), 밀리초까지
  private String generatedAtText() {
    return DateTimeFormatter.ISO_INSTANT.format(clock.instant().truncatedTo(ChronoUnit.MILLIS));
  }

  // 관리자 화면 시각은 서버 기본 시간대(Asia/Seoul) 기준 LocalDateTime
  private static LocalDateTime toAdminLocalTime(Instant instant) {
    return instant == null ? null : LocalDateTime.ofInstant(instant, ZoneId.systemDefault());
  }
}
