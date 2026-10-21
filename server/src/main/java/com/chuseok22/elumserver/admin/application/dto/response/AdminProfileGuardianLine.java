package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.member.infrastructure.entity.GuardianKind;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import java.time.LocalDateTime;

/**
 * 관리자 회원 상세: 이룸이를 함께 돌보는 보호자 한 줄
 *
 * @param displayName      이룸이 안에서 부르는 이름 ("엄마"). 비어 있으면 null
 * @param isViewedMember   지금 보고 있는 회원 본인인가
 */
public record AdminProfileGuardianLine(
  String memberId,
  String username,
  String displayName,
  GuardianKind kind,
  LocalDateTime joinedAt,
  MemberStatus memberStatus,
  boolean isViewedMember
) {

  /** 관계 행(계정 채워진 것) > 한 줄 */
  public static AdminProfileGuardianLine of(ProfileGuardian guardian, String viewedMemberId) {
    String memberId = guardian.getMember().getId();
    return new AdminProfileGuardianLine(
      memberId,
      guardian.getMember().getUsername(),
      guardian.getDisplayName() == null || guardian.getDisplayName().isBlank() ? null : guardian.getDisplayName(),
      guardian.getKind(),
      guardian.getJoinedAt(),
      guardian.getMember().getStatus(),
      memberId.equals(viewedMemberId)
    );
  }

  /** 역할 코드 > 표시 이름 (GUARDIAN 가족 보호자, CAREGIVER 기관 지도자) */
  public String kindLabel() {
    return kind == GuardianKind.CAREGIVER ? "기관 지도자" : "가족 보호자";
  }
}
