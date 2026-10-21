package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminDeviceLinkLine;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberConnections;
import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberProfileCard;
import com.chuseok22.elumserver.admin.application.dto.response.AdminProfileGuardianLine;
import com.chuseok22.elumserver.admin.application.dto.response.AdminProfileInviteLine;
import com.chuseok22.elumserver.admin.application.dto.response.AdminPushDeviceLine;
import com.chuseok22.elumserver.link.application.service.DeviceLinkService;
import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import com.chuseok22.elumserver.member.application.service.ProfileGuardianService;
import com.chuseok22.elumserver.member.application.service.ProfileInviteService;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileInvite;
import com.chuseok22.elumserver.notification.application.service.PushDeviceService;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * 관리자 회원 상세 연결 정보: 이룸이별 공동 보호자·초대 코드·이룸이 기기 조회, 푸시 기기 조회, 이룸이 기기 연결 해제
 * 조회는 상세 본문과 다른 트랜잭션 (실패해도 본문 트랜잭션이 롤백 전용이 되지 않음)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AdminMemberConnectionService {

  // 이룸이 카드마다 보여줄 초대 코드 최대 건수 (최신순)
  static final int INVITE_DISPLAY_LIMIT = 10;
  // 이룸이 카드마다 보여줄 지난 연결·발급 최대 건수 (지금 연결된 기기는 한도 없이 전부)
  static final int PAST_DEVICE_LINK_DISPLAY_LIMIT = 10;

  private final ProfileGuardianService profileGuardianService;
  private final ProfileInviteService profileInviteService;
  private final DeviceLinkService deviceLinkService;
  private final PushDeviceService pushDeviceService;

  /**
   * 연결 정보 조회: 이룸이 관계 > 이룸이들의 보호자·초대 코드·기기 연결·마지막 접속 (각 1회) > 푸시 기기
   * 이룸이 수만큼 쿼리하지 않음
   */
  @Transactional(readOnly = true, propagation = Propagation.REQUIRES_NEW)
  public AdminMemberConnections getConnections(String memberId) {
    LocalDateTime now = LocalDateTime.now();
    List<ProfileGuardian> guardianships = profileGuardianService.guardianshipsWithProfileOf(memberId);
    List<String> profileIds = guardianships.stream().map(guardianship -> guardianship.getProfile().getId()).toList();

    // 이룸이 id 별 묶음 (보호자, 초대 코드, 기기 연결). 묶음 안 순서는 조회 순서 그대로
    Map<String, List<ProfileGuardian>> guardiansByProfileId = profileGuardianService.guardiansWithMemberOf(profileIds)
      .stream().collect(Collectors.groupingBy(guardian -> guardian.getProfile().getId()));
    Map<String, List<ProfileInvite>> invitesByProfileId = profileInviteService.invitesOf(profileIds)
      .stream().collect(Collectors.groupingBy(ProfileInvite::getProfileId));
    List<DeviceLink> deviceLinks = deviceLinkService.linksOf(profileIds);
    Map<String, List<DeviceLink>> deviceLinksByProfileId = deviceLinks.stream()
      .collect(Collectors.groupingBy(DeviceLink::getProfileId));
    Map<String, LocalDateTime> lastSessionAtByLinkId = deviceLinkService.lastSessionAtByLinkId(deviceLinks);

    List<AdminMemberProfileCard> profileCards = guardianships.stream()
      .map(guardianship -> toProfileCard(
        guardianship, memberId,
        guardiansByProfileId.getOrDefault(guardianship.getProfile().getId(), List.of()),
        invitesByProfileId.getOrDefault(guardianship.getProfile().getId(), List.of()),
        deviceLinksByProfileId.getOrDefault(guardianship.getProfile().getId(), List.of()),
        lastSessionAtByLinkId, now))
      .toList();
    List<AdminPushDeviceLine> pushDevices = pushDeviceService.devicesOf(memberId).stream()
      .map(device -> AdminPushDeviceLine.of(device, now))
      .toList();
    return new AdminMemberConnections(profileCards, pushDevices, false);
  }

  /**
   * 이룸이 기기 연결 해제: 앱의 끊기와 같은 도메인 경로 > 감사 로그
   * 대상 확인(지금 연결됨, 이 회원이 그 이룸이 보호자)과 그 기기 세션만 폐기는 도메인이 함께 처리
   */
  @Transactional
  public void unlinkDevice(String memberId, String linkId, String adminUsername) {
    deviceLinkService.revoke(memberId, linkId);
    log.info("[admin device unlink] unlinked : linkId={}, viewedMember={}, admin={}", linkId, memberId, adminUsername);
  }

  /** 관계 행 + 이룸이의 보호자·초대 코드·기기 연결 > 이룸이 카드 */
  private AdminMemberProfileCard toProfileCard(
    ProfileGuardian guardianship, String viewedMemberId, List<ProfileGuardian> guardians,
    List<ProfileInvite> invites, List<DeviceLink> deviceLinks, Map<String, LocalDateTime> lastSessionAtByLinkId,
    LocalDateTime now
  ) {
    Profile profile = guardianship.getProfile();
    Map<String, String> nameByMemberId = guardianNamesOf(guardians);

    List<AdminProfileInviteLine> inviteLines = invites.stream()
      .limit(INVITE_DISPLAY_LIMIT)
      .map(invite -> AdminProfileInviteLine.of(invite, nameByMemberId, now))
      .toList();
    List<DeviceLink> shownDeviceLinks = selectShownDeviceLinks(deviceLinks);
    List<AdminDeviceLinkLine> deviceLinkLines = shownDeviceLinks.stream()
      .map(link -> AdminDeviceLinkLine.of(link, nameByMemberId, lastSessionAtByLinkId.get(link.getId()), now))
      .toList();

    return new AdminMemberProfileCard(
      profile.getId(),
      profile.getNickname(),
      profile.getCharacter(),
      profile.getTotalStars(),
      // 지연 로딩 컬렉션이라 트랜잭션 안에서 복사 (화면은 트랜잭션 밖에서 그림)
      Set.copyOf(profile.getSupportGoals()),
      guardianship.getJoinedAt(),
      guardians.stream().map(guardian -> AdminProfileGuardianLine.of(guardian, viewedMemberId)).toList(),
      inviteLines,
      invites.size() - inviteLines.size(),
      deviceLinkLines,
      deviceLinks.size() - shownDeviceLinks.size()
    );
  }

  /** 보여줄 기기 연결 고르기: 지금 연결된 것 전부 + 지난 기록은 최근 것만 (최신순 유지) */
  private List<DeviceLink> selectShownDeviceLinks(List<DeviceLink> deviceLinks) {
    List<DeviceLink> shown = new ArrayList<>();
    int pastCount = 0;
    for (DeviceLink link : deviceLinks) {
      if (link.isLinked()) {
        shown.add(link);
      } else if (pastCount < PAST_DEVICE_LINK_DISPLAY_LIMIT) {
        shown.add(link);
        pastCount++;
      }
    }
    return shown;
  }

  /** 보호자들 > memberId 별 표시 이름 (이룸이 안 이름, 없으면 아이디) */
  private Map<String, String> guardianNamesOf(List<ProfileGuardian> guardians) {
    Map<String, String> nameByMemberId = new HashMap<>();
    for (ProfileGuardian guardian : guardians) {
      String displayName = guardian.getDisplayName();
      nameByMemberId.put(guardian.getMember().getId(),
        displayName == null || displayName.isBlank() ? guardian.getMember().getUsername() : displayName);
    }
    return nameByMemberId;
  }
}
