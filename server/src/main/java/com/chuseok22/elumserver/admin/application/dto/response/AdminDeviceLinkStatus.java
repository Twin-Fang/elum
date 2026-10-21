package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.link.core.CodeDigest;
import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.RequiredArgsConstructor;

/**
 * 관리자 회원 상세의 이룸이 기기 연결 상태 6개: 연결됨, 암호 대기 중, 암호 만료, 시도 초과로 막힘, 연결 끊김, 암호 폐기
 * 판정 순서: 연결 이력 있음(연결됨·끊김) > 폐기(틀린 횟수로 막힘 구분) > 만료 > 대기 중
 */
@Getter
@RequiredArgsConstructor
public enum AdminDeviceLinkStatus {

  LINKED("연결됨", "badge-success"),
  PENDING("암호 대기 중", "badge-info"),
  CODE_EXPIRED("암호 만료", "badge-warning"),
  BLOCKED("시도 초과로 막힘", "badge-error"),
  // 보호자·관리자가 끊었거나 이룸이 기기가 로그아웃함
  UNLINKED("연결 끊김", "badge-ghost"),
  // 같은 보호자가 새 암호를 내 이전 암호가 폐기됨
  CODE_REVOKED("암호 폐기", "badge-ghost");

  private final String label;
  // daisyUI 배지 색 클래스
  private final String badgeClass;

  /** 연결 행 > 지금 시각 기준 상태 */
  public static AdminDeviceLinkStatus of(DeviceLink link, LocalDateTime now) {
    if (link.getRedeemedAt() != null) {
      return link.getRevokedAt() == null ? LINKED : UNLINKED;
    }
    if (link.getRevokedAt() != null) {
      return link.getFailedAttempts() >= CodeDigest.MAX_FAILED_ATTEMPTS ? BLOCKED : CODE_REVOKED;
    }
    if (!link.getExpiresAt().isAfter(now)) {
      return CODE_EXPIRED;
    }
    return PENDING;
  }

  /** 운영자가 먼저 봐야 하는 상태인가 (막힘) */
  public boolean isProblem() {
    return this == BLOCKED;
  }
}
