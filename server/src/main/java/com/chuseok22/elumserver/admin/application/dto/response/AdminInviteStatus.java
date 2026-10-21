package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.link.core.CodeDigest;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileInvite;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.RequiredArgsConstructor;

/**
 * 관리자 회원 상세의 초대 코드 상태 5개: 사용 가능, 사용됨, 만료, 시도 초과로 막힘, 폐기
 * 판정 순서: 사용됨 > 폐기(틀린 횟수로 막힘 구분) > 만료 > 사용 가능
 */
@Getter
@RequiredArgsConstructor
public enum AdminInviteStatus {

  REDEEMABLE("사용 가능", "badge-success"),
  REDEEMED("사용됨", "badge-info"),
  EXPIRED("만료", "badge-warning"),
  BLOCKED("시도 초과로 막힘", "badge-error"),
  // 같은 보호자가 새 코드를 냈거나, 낸 보호자가 이룸이에서 나감
  REVOKED("폐기", "badge-ghost");

  private final String label;
  // daisyUI 배지 색 클래스
  private final String badgeClass;

  /** 초대 코드 행 > 지금 시각 기준 상태 */
  public static AdminInviteStatus of(ProfileInvite invite, LocalDateTime now) {
    if (invite.getRedeemedAt() != null) {
      return REDEEMED;
    }
    if (invite.getRevokedAt() != null) {
      return invite.getFailedAttempts() >= CodeDigest.MAX_FAILED_ATTEMPTS ? BLOCKED : REVOKED;
    }
    if (!invite.getExpiresAt().isAfter(now)) {
      return EXPIRED;
    }
    return REDEEMABLE;
  }

  /** 운영자가 먼저 봐야 하는 상태인가 (막힘) */
  public boolean isProblem() {
    return this == BLOCKED;
  }
}
