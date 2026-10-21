package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.member.infrastructure.entity.ProfileInvite;
import java.time.LocalDateTime;
import java.util.Map;

/**
 * 관리자 회원 상세: 초대 코드 한 줄 (코드 원문은 서버에 없어 표시하지 않음)
 *
 * @param issuedByName   낸 보호자 이름. 이룸이에서 나간 사람이면 null
 * @param redeemedByName 합류한 보호자 이름. 아직 안 썼거나 나간 사람이면 null
 */
public record AdminProfileInviteLine(
  String id,
  AdminInviteStatus status,
  String issuedByMemberId,
  String issuedByName,
  LocalDateTime issuedAt,
  LocalDateTime expiresAt,
  String redeemedByMemberId,
  String redeemedByName,
  LocalDateTime redeemedAt,
  LocalDateTime revokedAt,
  int failedAttempts
) {

  /** 초대 코드 행 + 보호자 이름표(memberId > 이름) > 한 줄 */
  public static AdminProfileInviteLine of(ProfileInvite invite, Map<String, String> nameByMemberId, LocalDateTime now) {
    return new AdminProfileInviteLine(
      invite.getId(),
      AdminInviteStatus.of(invite, now),
      invite.getIssuedBy(),
      nameByMemberId.get(invite.getIssuedBy()),
      invite.getCreatedAt(),
      invite.getExpiresAt(),
      invite.getRedeemedBy(),
      invite.getRedeemedBy() == null ? null : nameByMemberId.get(invite.getRedeemedBy()),
      invite.getRedeemedAt(),
      invite.getRevokedAt(),
      invite.getFailedAttempts()
    );
  }
}
