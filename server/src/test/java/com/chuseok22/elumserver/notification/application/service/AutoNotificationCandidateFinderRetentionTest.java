package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.license.application.service.SubscriptionStatusService;
import com.chuseok22.elumserver.link.application.service.DeviceLinkStatusQueryService;
import com.chuseok22.elumserver.member.application.service.MemberAdminLookupService;
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
import java.util.Collection;
import java.util.List;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 리텐션 4종(#1409)이 조건과 다른 사람을 고르면 이미 한 사람을 재촉하거나 기기 없는 사람에게 "시작 전" 알림이 간다
/// 쿼리 자체는 RetentionCandidateQueryIT (실제 Postgres), 여기서는 고른 줄을 거르는 규칙만
class AutoNotificationCandidateFinderRetentionTest {

  private static final LocalDateTime NOW = LocalDateTime.of(2026, 11, 14, 12, 0);
  private static final LocalDate TODAY = NOW.toLocalDate();

  private final RoutineEngagementQueryService routineQuery = mock(RoutineEngagementQueryService.class);
  private final MemberEngagementQueryService memberQuery = mock(MemberEngagementQueryService.class);
  private final MemberAdminLookupService memberAdminLookupService = mock(MemberAdminLookupService.class);
  private final ElumiStreakService streakService = mock(ElumiStreakService.class);
  private final DeviceLinkStatusQueryService linkStatus = mock(DeviceLinkStatusQueryService.class);
  private final ProfileGuardianService profileGuardianService = mock(ProfileGuardianService.class);
  private final AutoNotificationCandidateFinder finder = new AutoNotificationCandidateFinder(routineQuery, memberQuery,
    memberAdminLookupService, mock(TalkPopularityService.class), mock(SubscriptionStatusService.class), streakService,
    linkStatus, profileGuardianService);

  @BeforeEach
  @SuppressWarnings("unchecked")
  void allMembersActive() {
    when(memberAdminLookupService.findActiveMemberIds(anyCollection()))
      .thenAnswer(invocation -> List.copyOf((Collection<String>) invocation.getArgument(0)));
    when(memberQuery.profileNamesByMemberId(anyCollection())).thenReturn(Map.of(
      "g-a", Map.of("p-a", "하늘"), "g-b", Map.of("p-a", "하늘", "p-other", "바다")));
  }

  @Test
  @DisplayName("첫 일과 만들기: 가입 1일째·3일째 날짜 칸으로 묻고, 일과를 만든 보호자는 뺀다")
  void onboardedNoRoutine_asksDay1AndDay3_excludesCreators() {
    LocalDateTime day1Start = TODAY.minusDays(1).atStartOfDay();
    LocalDateTime day3Start = TODAY.minusDays(3).atStartOfDay();
    when(memberQuery.findActiveOnboardedMemberIdsJoinedBetween(day1Start, day1Start.plusDays(1)))
      .thenReturn(List.of("d1", "d1-creator"));
    when(memberQuery.findActiveOnboardedMemberIdsJoinedBetween(day3Start, day3Start.plusDays(1)))
      .thenReturn(List.of("d3"));
    when(routineQuery.findCreatorIdsAmong(anyCollection())).thenReturn(Set.of("d1-creator"));

    List<AutoNotificationCandidate> candidates = finder.find(AutoNotificationType.ONBOARDED_NO_ROUTINE, NOW);

    assertThat(candidates).extracting(AutoNotificationCandidate::memberId).containsExactly("d1", "d3");
  }

  @Test
  @DisplayName("보낸 일과 시작 전: 이룸이 기기가 연결된 일과의 보호자만, 문구 값은 그 일과 제목")
  void sentNotDone_keepsOnlyLinkedProfiles() {
    when(routineQuery.findMembersSentTodayWithoutProgress(TODAY)).thenReturn(List.of(
      new SentRoutineSummary("g-a", "p-a", "양치"), new SentRoutineSummary("g-unlinked", "p-unlinked", "세수")));
    when(linkStatus.findLinkedProfileIds(anyList())).thenReturn(Set.of("p-a"));

    List<AutoNotificationCandidate> candidates = finder.find(AutoNotificationType.SENT_NOT_DONE, NOW);

    assertThat(candidates).containsExactly(new AutoNotificationCandidate("g-a", "하늘", "양치", null));
  }

  @Test
  @DisplayName("연속 기록: 최소 2일로 묻고, 그 이룸이의 보호자 모두에게 그 이룸이 이름으로")
  void streakAtRisk_sendsToEveryGuardianWithThatProfileName() {
    when(streakService.findProfilesAtRiskToday(TODAY, AutoNotificationCandidateFinder.STREAK_AT_RISK_MINIMUM_DAYS))
      .thenReturn(List.of(new ProfileStreak("p-a", 3)));
    when(profileGuardianService.guardianMemberIdsOf("p-a")).thenReturn(List.of("g-a", "g-b"));

    List<AutoNotificationCandidate> candidates = finder.find(AutoNotificationType.STREAK_AT_RISK, NOW);

    assertThat(candidates).containsExactly(
      new AutoNotificationCandidate("g-a", "하늘", null, null),
      new AutoNotificationCandidate("g-b", "하늘", null, null));
    assertThat(AutoNotificationCandidateFinder.STREAK_AT_RISK_MINIMUM_DAYS).isGreaterThanOrEqualTo(2);
  }

  @Test
  @DisplayName("기기 연결 안내: 처음 보낸 날을 오늘 뺀 3일 칸으로 묻고, 기기가 연결된 이룸이는 뺀다")
  void linkPending_asksThreeDayWindow_excludesLinked() {
    LocalDateTime todayStart = TODAY.atStartOfDay();
    when(routineQuery.findMembersFirstSentBetween(todayStart.minusDays(3), todayStart)).thenReturn(List.of(
      new SentRoutineSummary("g-a", "p-a", "양치"), new SentRoutineSummary("g-linked", "p-linked", "세수")));
    when(linkStatus.findLinkedProfileIds(anyList())).thenReturn(Set.of("p-linked"));

    List<AutoNotificationCandidate> candidates = finder.find(AutoNotificationType.LINK_PENDING, NOW);

    assertThat(candidates).extracting(AutoNotificationCandidate::memberId).containsExactly("g-a");
  }

  @Test
  @DisplayName("탈퇴 등 활성 아닌 보호자는 어떤 규칙에서도 빠진다")
  void inactiveMembers_areExcluded() {
    when(routineQuery.findMembersSentTodayWithoutProgress(any())).thenReturn(List.of(
      new SentRoutineSummary("g-a", "p-a", "양치"), new SentRoutineSummary("withdrawn", "p-w", "세수")));
    when(linkStatus.findLinkedProfileIds(anyList())).thenReturn(Set.of("p-a", "p-w"));
    when(memberAdminLookupService.findActiveMemberIds(anyCollection())).thenReturn(List.of("g-a"));

    assertThat(finder.find(AutoNotificationType.SENT_NOT_DONE, NOW))
      .extracting(AutoNotificationCandidate::memberId).containsExactly("g-a");
  }
}
