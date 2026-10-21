package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;

/**
 * 관리자 회원 상세의 이룸이 카드 하나: 이룸이 기본 정보, 함께 돌보는 보호자, 초대 코드, 이룸이 기기 연결
 * 초대 코드·기기 연결은 최근 것만 담고 나머지는 숨긴 건수로 센다
 *
 * @param viewedMemberJoinedAt 보고 있는 회원이 이 이룸이에 합류한 시각
 * @param hiddenInviteCount    표시 한도를 넘어 숨긴 초대 코드 건수
 * @param hiddenDeviceLinkCount 표시 한도를 넘어 숨긴 지난 연결·발급 건수
 */
public record AdminMemberProfileCard(
  String profileId,
  String nickname,
  CharacterType character,
  Integer totalStars,
  Set<SupportGoal> supportGoals,
  LocalDateTime viewedMemberJoinedAt,
  List<AdminProfileGuardianLine> guardians,
  List<AdminProfileInviteLine> invites,
  int hiddenInviteCount,
  List<AdminDeviceLinkLine> deviceLinks,
  int hiddenDeviceLinkCount
) {

  /** 지금 연결된 이룸이 기기 대수 */
  public long linkedDeviceCount() {
    return deviceLinks.stream().filter(link -> link.status() == AdminDeviceLinkStatus.LINKED).count();
  }

  /** 지금 넣을 수 있는 초대 코드 개수 */
  public long redeemableInviteCount() {
    return invites.stream().filter(invite -> invite.status() == AdminInviteStatus.REDEEMABLE).count();
  }

  /** 시도 초과로 막힌 초대 코드·연결 암호가 있는가 (표시 중인 것 기준) */
  public boolean hasBlockedCode() {
    return invites.stream().anyMatch(invite -> invite.status().isProblem())
      || deviceLinks.stream().anyMatch(link -> link.status().isProblem());
  }
}
