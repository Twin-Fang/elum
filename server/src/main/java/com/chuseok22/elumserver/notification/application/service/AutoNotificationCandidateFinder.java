package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.license.application.service.MemberSubscriptionStatus;
import com.chuseok22.elumserver.license.application.service.SubscriptionStatusService;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.member.application.service.MemberAdminLookupService;
import com.chuseok22.elumserver.member.application.service.MemberEngagementQueryService;
import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.routine.application.service.RoutineEngagementQueryService;
import com.chuseok22.elumserver.routine.application.service.RoutineEngagementQueryService.SentRoutineSummary;
import com.chuseok22.elumserver.talk.application.service.TalkPopularityService;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 자동 알림 종류별 받을 사람 고르기 (#1275): 조건 조회 > 활성 회원만 > 문구 값(이룸이 이름·일과·날짜) 채우기
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
    };
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
    Map<String, String> dateTextByMemberId = new HashMap<>();
    for (String memberId : memberIdsLastActiveBetween(now.minusDays(PRO_ENDING_ACTIVE_DAYS), now.plusDays(OPEN_END_DAYS))) {
      MemberSubscriptionStatus status = subscriptionStatusService.statusOf(memberId);
      if (isEndingOn(status, endingDate)) {
        dateTextByMemberId.put(memberId, AutoNotificationTemplate.toKoreanMonthDay(endingDate));
      }
    }
    return withValues(List.copyOf(dateTextByMemberId.keySet()), dateTextByMemberId, now);
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

  // 회원으로 고른 사람: 첫 이룸이 이름, 최근 보낸 일과 제목, 날짜 글자(있으면)
  private List<AutoNotificationCandidate> withValues(List<String> memberIds, Map<String, String> dateTextByMemberId,
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
        latestRoutine == null ? null : latestRoutine.routineTitle(), dateTextByMemberId.get(memberId));
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
