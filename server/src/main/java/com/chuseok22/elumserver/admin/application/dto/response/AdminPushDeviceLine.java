package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.admin.application.format.AdminValuePreview;
import com.chuseok22.elumserver.notification.core.PushPlatform;
import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import java.time.LocalDateTime;

/**
 * 관리자 회원 상세: 푸시 받는 보호자 기기 한 줄 (토큰은 앞 6자만)
 *
 * @param isStale 마지막 등록이 오래돼 토큰이 죽었을 수 있는가
 */
public record AdminPushDeviceLine(
  PushPlatform platform,
  String localeCode,
  String tokenPreview,
  LocalDateTime createdAt,
  LocalDateTime lastRegisteredAt,
  boolean isStale
) {

  // 이보다 오래 등록이 없으면 오래됨 표시 (30일)
  public static final int STALE_AFTER_DAYS = 30;

  /** 푸시 기기 행 > 한 줄 (토큰 원문은 담지 않음) */
  public static AdminPushDeviceLine of(PushDevice device, LocalDateTime now) {
    LocalDateTime lastRegisteredAt = device.getLastRegisteredAt();
    return new AdminPushDeviceLine(
      device.getPlatform(),
      device.getLocale() == null ? null : device.getLocale().code(),
      AdminValuePreview.previewOf(device.getToken()),
      device.getCreatedAt(),
      lastRegisteredAt,
      lastRegisteredAt != null && lastRegisteredAt.isBefore(now.minusDays(STALE_AFTER_DAYS))
    );
  }

  /// 오래됨 기준 일수 (화면 문구용)
  public int staleAfterDays() {
    return STALE_AFTER_DAYS;
  }
}
