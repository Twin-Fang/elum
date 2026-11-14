package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.license.application.service.MemberSubscriptionStatus;
import com.chuseok22.elumserver.license.application.service.SubscriptionStatusService;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.member.application.service.MemberAdminLookupService;
import com.chuseok22.elumserver.link.application.service.DeviceLinkStatusQueryService;
import com.chuseok22.elumserver.member.application.service.MemberEngagementQueryService;
import com.chuseok22.elumserver.member.application.service.ProfileGuardianService;
import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.routine.application.service.ElumiStreakService;
import com.chuseok22.elumserver.routine.application.service.ElumiStreakService.ProfileStreak;
import com.chuseok22.elumserver.routine.application.service.RoutineEngagementQueryService;
import com.chuseok22.elumserver.routine.application.service.RoutineEngagementQueryService.SentRoutineSummary;
import com.chuseok22.elumserver.talk.application.service.TalkPopularityService;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 자동 알림 종류별 받을 사람 고르기 (#1275, 리텐션 4종 #1409): 조건 조회 > 활성 회원만 > 문구 값(이룸이 이름·일과·날짜) 채우기
 * 하루 상한·간격·끄기는 AutoNotificationRunner 몫. "앱을 연 때" = Member.lastActivityAt
 */
@Component
@RequiredArgsConstructor
public class AutoNotificationCandidateFinder {

  // 다시 찾기: 이 일수 이상 안 연 보호자, 이 일수 넘게 안 연 보호자는 제외 (떠난 계정을 매주 깨우지 않음)
  static final int COMEBACK_INACTIVE_DAYS = 3;
  static final int COMEBACK_GIVE_UP_DAYS = 60;
  // 이야기 인기: 최근 이 일수 안에 이 수 이상 보호자가 담은 글, 받는 사람은 이 일수 안에 앱을 연 보호자
  static final int TALK_POPULAR_WINDOW_DAYS = 7;
  static final long TALK_POPULAR_MINIMUM_IMPORTER_COUNT = 3;
  static final int TALK_POPULAR_ACTIVE_DAYS = 30;
  // Pro 끝나기 전: 끝나는 날까지 남은 일수, 살펴볼 보호자 (이 일수 안에 앱을 연 보호자)
  static final int PRO_ENDING_DAYS_BEFORE = 7;
  static final int PRO_ENDING_ACTIVE_DAYS = 90;
  // 첫 일과 축하: 이 시간 안에 끝난 첫 일과 (야간 동안 쌓인 것까지)
  static final int FIRST_ROUTINE_LOOKBACK_HOURS = 24;
  // 첫 일과 만들기 안내: 가입 뒤 이 날째에 한 번씩 (가입 다음 날 = 1)
  static final List<Integer> ONBOARDED_NUDGE_DAYS_AFTER_SIGNUP = List.of(1, 3);
  // 연속 기록 이어 가기: 어제까지 이 일수 이상 이어진 이룸이
  static final int STREAK_AT_RISK_MINIMUM_DAYS = 2;
  // 기기 연결 안내: 처음 보낸 일과가 이 일수 안(오늘 제외)에 만들어진 보호자 (상한에 밀린 날 다음 날 다시 시도)
  static final int LINK_PENDING_WINDOW_DAYS = 3;
  // {일과} 값을 찾는 최근 기간
  static final int RECENT_ROUTINE_DAYS = 30;
  // 기간 상한을 열어 둘 때 쓰는 여유 (지금 + 1일)
  private static final int OPEN_END_DAYS = 1;
  // 끝나는 날 알림 대상 혜택 3개: 선물, 가입 체험, 관리자 기간 발급 (스토어 구독은 자동 갱신이라 제외)
  private static final Set<SubscriptionSource> ENDING_REMINDER_SOURCES =
    Set.of(SubscriptionSource.PRO_GIFT, SubscriptionSource.PROMO, SubscriptionSource.MANUAL);

  private final RoutineEngagementQueryService routineEngagementQueryService;
  private final MemberEngagementQueryService memberEngagementQueryService;
  private final MemberAdminLookupService memberAdminLookupService;
  private final TalkPopularityService talkPopularityService;
  private final SubscriptionStatusService subscriptionStatusService;
  private final ElumiStreakService elumiStreakService;
  private final DeviceLinkStatusQueryService deviceLinkStatusQueryService;
  private final ProfileGuardianService profileGuardianService;

  /// 종류 > 받을 사람 (활성 회원만, 문구 값 채움)
  public List<AutoNotificationCandidate> find(AutoNotificationType type, LocalDateTime now) {
    return switch (type) {
      case FIRST_ROUTINE_DONE -> withValues(
        routineEngagementQueryService.findFirstCompletionsSince(now.minusHours(FIRST_ROUTINE_LOOKBACK_HOURS)));
      case DAILY_ROUTINE_NUDGE -> withValues(
        routineEngagementQueryService.findMembersSentYesterdayNotToday(now.toLocalDate()));
      case COMEBACK -> withValues(memberIdsLastActiveBetween(
        now.minusDays(COMEBACK_GIVE_UP_DAYS), now.minusDays(COMEBACK_INACTIVE_DAYS)), Map.of(), now);
      case TALK_POPULAR -> findTalkPopular(now);
      case PRO_GIFT_ENDING -> findProEnding(now);
      case ONBOARDED_NO_ROUTINE -> findOnboardedWithoutRoutine(now);
      case SENT_NOT_DONE -> withValues(onlyLinked(
        routineEngagementQueryService.findMembersSentTodayWithoutProgress(now.toLocalDate()), true));
      case STREAK_AT_RISK -> findStreakAtRisk(now.toLocalDate());
      case LINK_PENDING -> withValues(onlyLinked(routineEngagementQueryService.findMembersFirstSentBetween(
        now.toLocalDate().atStartOfDay().minusDays(LINK_PENDING_WINDOW_DAYS), now.toLocalDate().atStartOfDay()), false));
    };
  }

  // 가입 1일째·3일째 온보딩 마친 보호자 > 일과를 만든 적 있는 사람 빼기
  private List<AutoNotificationCandidate> findOnboardedWithoutRoutine(LocalDateTime now) {
    List<String> joinedMemberIds = new ArrayList<>();
    for (int daysAfterSignup : ONBOARDED_NUDGE_DAYS_AFTER_SIGNUP) {
      LocalDateTime signupDayStart = now.toLocalDate().minusDays(daysAfterSignup).atStartOfDay();
      joinedMemberIds.addAll(memberEngagementQueryService.findActiveOnboardedMemberIdsJoinedBetween(signupDayStart,
        signupDayStart.plusDays(1)));
    }
    Set<String> creatorIds = routineEngagementQueryService.findCreatorIdsAmong(joinedMemberIds);
    return withValues(joinedMemberIds.stream().filter(memberId -> !creatorIds.contains(memberId)).toList(),
      Map.of(), now);
  }

  // 오늘 끊길 수 있는 이룸이 > 그 이룸이의 보호자 전부 (문구의 이름은 그 이룸이)
  private List<AutoNotificationCandidate> findStreakAtRisk(LocalDate today) {
    List<SentRoutineSummary> guardianRows = new ArrayList<>();
    for (ProfileStreak streak : elumiStreakService.findProfilesAtRiskToday(today, STREAK_AT_RISK_MINIMUM_DAYS)) {
      for (String guardianMemberId : profileGuardianService.guardianMemberIdsOf(streak.profileId())) {
        guardianRows.add(new SentRoutineSummary(guardianMemberId, streak.profileId(), null));
      }
    }
    return withValues(guardianRows);
  }

  // 그 일과의 이룸이 기기 연결 상태로 거르기 (shouldBeLinked: true 연결된 것만, false 연결 안 된 것만)
  private List<SentRoutineSummary> onlyLinked(List<SentRoutineSummary> routines, boolean shouldBeLinked) {
    if (routines.isEmpty()) {
      return routines;
    }
    Set<String> linkedProfileIds = deviceLinkStatusQueryService.findLinkedProfileIds(
      routines.stream().map(SentRoutineSummary::profileId).toList());
    return routines.stream()
      .filter(routine -> linkedProfileIds.contains(routine.profileId()) == shouldBeLinked)
      .toList();
  }

  private List<AutoNotificationCandidate> findTalkPopular(LocalDateTime now) {
    if (!talkPopularityService.hasPostImportedAtLeastSince(now.minusDays(TALK_POPULAR_WINDOW_DAYS),
      TALK_POPULAR_MINIMUM_IMPORTER_COUNT)) {
      return List.of();
    }
    return withValues(memberIdsLastActiveBetween(now.minusDays(TALK_POPULAR_ACTIVE_DAYS), now.plusDays(OPEN_END_DAYS)),
      Map.of(), now);
  }

  // 최근 연 보호자마다 지금 요금제 확인 > Pro 혜택이 정확히 7일 뒤(KST 날짜) 끝나는 사람 (그날 하루만 맞아 혜택마다 한 번)
  private List<AutoNotificationCandidate> findProEnding(LocalDateTime now) {
    LocalDate endingDate = now.toLocalDate().plusDays(PRO_ENDING_DAYS_BEFORE);
    Map<String, LocalDate> endingDateByMemberId = new HashMap<>();
    for (String memberId : memberIdsLastActiveBetween(now.minusDays(PRO_ENDING_ACTIVE_DAYS), now.plusDays(OPEN_END_DAYS))) {
      MemberSubscriptionStatus status = subscriptionStatusService.statusOf(memberId);
      if (isEndingOn(status, endingDate)) {
        endingDateByMemberId.put(memberId, endingDate);
      }
    }
    return withValues(List.copyOf(endingDateByMemberId.keySet()), endingDateByMemberId, now);
  }

  static boolean isEndingOn(MemberSubscriptionStatus status, LocalDate endingDate) {
    return status.plan() == PlanType.PRO && ENDING_REMINDER_SOURCES.contains(status.source())
      && status.expiresAt() != null && status.expiresAt().toLocalDate().equals(endingDate);
  }

  private List<String> memberIdsLastActiveBetween(LocalDateTime from, LocalDateTime to) {
    return memberEngagementQueryService.findActiveMemberIdsLastActiveBetween(from, to);
  }

  // 일과에서 고른 사람: 그 일과의 이룸이·제목을 문구 값으로
  private List<AutoNotificationCandidate> withValues(List<SentRoutineSummary> routines) {
    List<String> activeMemberIds = memberAdminLookupService.findActiveMemberIds(
      routines.stream().map(SentRoutineSummary::memberId).toList());
    Map<String, Map<String, String>> profileNamesByMemberId =
      memberEngagementQueryService.profileNamesByMemberId(activeMemberIds);
    Set<String> activeMemberIdSet = Set.copyOf(activeMemberIds);
    return routines.stream()
      .filter(routine -> activeMemberIdSet.contains(routine.memberId()))
      .map(routine -> new AutoNotificationCandidate(routine.memberId(),
        childNameOf(profileNamesByMemberId.get(routine.memberId()), routine.profileId()), routine.routineTitle(), null))
      .toList();
  }

  // 회원으로 고른 사람: 첫 이룸이 이름, 최근 보낸 일과 제목, 날짜(있으면)
  private List<AutoNotificationCandidate> withValues(List<String> memberIds, Map<String, LocalDate> dateByMemberId,
    LocalDateTime now) {
    if (memberIds.isEmpty()) {
      return List.of();
    }
    Map<String, Map<String, String>> profileNamesByMemberId = memberEngagementQueryService.profileNamesByMemberId(memberIds);
    Map<String, SentRoutineSummary> latestRoutineByMemberId =
      routineEngagementQueryService.findLatestSentByMembers(memberIds, now.minusDays(RECENT_ROUTINE_DAYS));
    return memberIds.stream().map(memberId -> {
      SentRoutineSummary latestRoutine = latestRoutineByMemberId.get(memberId);
      return new AutoNotificationCandidate(memberId,
        childNameOf(profileNamesByMemberId.get(memberId), latestRoutine == null ? null : latestRoutine.profileId()),
        latestRoutine == null ? null : latestRoutine.routineTitle(), dateByMemberId.get(memberId));
    }).toList();
  }

  // 그 이룸이 이름, 없으면 먼저 합류한 이룸이 이름, 이룸이가 없으면 null (문구는 기본 말)
  private static String childNameOf(Map<String, String> profileNameById, String preferredProfileId) {
    if (profileNameById == null || profileNameById.isEmpty()) {
      return null;
    }
    if (preferredProfileId != null && profileNameById.containsKey(preferredProfileId)) {
      return profileNameById.get(preferredProfileId);
    }
    return profileNameById.values().iterator().next();
  }
}
