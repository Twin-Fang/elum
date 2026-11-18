package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsQueries;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.FirstDayActivationCounts;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.FunnelCounts;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.RetentionCohortCounts;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.SuggestionCandidate;
import com.chuseok22.elumserver.admin.infrastructure.repository.AdminUsageAnalyticsRows.WeeklyCount;
import com.chuseok22.elumserver.common.application.stats.StatsBucketCount;
import com.chuseok22.elumserver.common.application.stats.StatsBucketUnit;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import com.chuseok22.elumserver.member.application.service.MemberStatsService;
import com.chuseok22.elumserver.member.core.MemberAccountKind;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberDailyVisitRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 사용 분석 집계 SQL (#1436)을 실제 Postgres 로 검증. 평소 빌드에서는 건너뜀
 * 목 테스트로는 native SQL(가입 단계 exists, 가입 주 리텐션 날짜 경계, 계정 종류 제외)이 맞는지 못 봄. 표는 ddl-auto: update 가 만듦
 * 고정 데이터는 2001-01-01(월) 주에 둬서 운영 사본 DB 의 다른 회원과 섞이지 않게 함
 *
 * <pre>
 * ELUM_IT_DB_URL=jdbc:postgresql://localhost:5432/elum_it_1436 ./gradlew test --tests '*AdminUsageAnalyticsQueryIT'
 * </pre>
 */
@SpringBootTest(properties = {
  "spring.datasource.url=${ELUM_IT_DB_URL:jdbc:postgresql://localhost:5432/elum}",
  "spring.datasource.username=${ELUM_IT_DB_USERNAME:elum}",
  "spring.datasource.password=${ELUM_IT_DB_PASSWORD:pw}",
  "spring.flyway.enabled=false",
  "spring.jpa.hibernate.ddl-auto=update",
  "gemini.api-key=rehearsal-invalid"
})
@EnabledIfEnvironmentVariable(named = "ELUM_IT_DB_URL", matches = ".+")
class AdminUsageAnalyticsQueryIT {

  /// 고정 데이터 가입 주 (월요일)
  private static final LocalDate COHORT_WEEK = LocalDate.of(2001, 1, 1);

  @Autowired private AdminUsageAnalyticsQueries usageAnalyticsQueries;
  @Autowired private MemberStatsService memberStatsService;
  @Autowired private MemberRepository memberRepository;
  @Autowired private ProfileRepository profileRepository;
  @Autowired private ProfileGuardianRepository profileGuardianRepository;
  @Autowired private RoutineRepository routineRepository;
  @Autowired private RoutineStepRepository routineStepRepository;
  @Autowired private DeviceLinkRepository deviceLinkRepository;
  @Autowired private SubscriptionRepository subscriptionRepository;
  @Autowired private MemberDailyVisitRepository memberDailyVisitRepository;
  @Autowired private NamedParameterJdbcTemplate jdbcTemplate;
  @Autowired private TransactionTemplate transactionTemplate;

  private final String prefix = "it1436_" + UUID.randomUUID().toString().substring(0, 8) + "_";
  private final List<String> createdMemberIds = new ArrayList<>();
  private final List<String> createdProfileIds = new ArrayList<>();
  private Member storeBuyer;
  private Member routineOnly;
  private Member exampleOnly;
  private Member testAccount;

  // 일반 3명(결제까지 간 A, 일과만 만든 B, 예시 일과만 있는 C) + 테스트 계정 D(모든 단계)
  @BeforeEach
  void setUp() {
    storeBuyer = guardianJoinedAt("a", COHORT_WEEK.atTime(10, 0), MemberAccountKind.NORMAL, null);
    routineOnly = guardianJoinedAt("b", COHORT_WEEK.plusDays(1).atTime(10, 0), MemberAccountKind.NORMAL, null);
    exampleOnly = guardianJoinedAt("c", COHORT_WEEK.plusDays(2).atTime(10, 0), MemberAccountKind.NORMAL, "내부 시연용");
    testAccount = guardianJoinedAt("d", COHORT_WEEK.atTime(11, 0), MemberAccountKind.TEST, "내부");

    completedStep(routine(storeBuyer, false));
    linkDevice(storeBuyer);
    storePurchase(storeBuyer);
    visit(storeBuyer, COHORT_WEEK.plusDays(8));
    visit(storeBuyer, COHORT_WEEK.plusDays(29));

    routine(routineOnly, false);
    visit(routineOnly, COHORT_WEEK.plusDays(15));

    routine(exampleOnly, true);

    completedStep(routine(testAccount, false));
    linkDevice(testAccount);
    visit(testAccount, COHORT_WEEK.plusDays(8));
  }

  @AfterEach
  void cleanUp() {
    MapSqlParameterSource ids = new MapSqlParameterSource("memberIds", createdMemberIds)
      .addValue("profileIds", createdProfileIds);
    transactionTemplate.executeWithoutResult(status -> {
      jdbcTemplate.update("delete from routine_step where routine_id in "
        + "(select id from routine where created_by in (:memberIds))", ids);
      jdbcTemplate.update("delete from routine where created_by in (:memberIds)", ids);
      jdbcTemplate.update("delete from device_link where member_id in (:memberIds)", ids);
      jdbcTemplate.update("delete from subscription where member_id in (:memberIds)", ids);
      jdbcTemplate.update("delete from member_daily_visit where member_id in (:memberIds)", ids);
      jdbcTemplate.update("delete from profile_guardian where member_id in (:memberIds)", ids);
      jdbcTemplate.update("delete from profile where id in (:profileIds)", ids);
      jdbcTemplate.update("delete from member where id in (:memberIds)", ids);
    });
  }

  @Test
  @DisplayName("가입 단계: 일반 계정만 세고(예시 일과는 일과 만듦 아님), 모두 포함이면 테스트 계정도 센다")
  void funnel_countsNormalAccountsOnlyByDefault() {
    FunnelCounts normalOnly = usageAnalyticsQueries.countFunnel(cohortFrom(), cohortTo(), false);
    FunnelCounts includingAll = usageAnalyticsQueries.countFunnel(cohortFrom(), cohortTo(), true);

    assertThat(normalOnly).isEqualTo(new FunnelCounts(3, 2, 1, 1, 1));
    assertThat(includingAll).isEqualTo(new FunnelCounts(4, 3, 2, 2, 1));
  }

  @Test
  @DisplayName("가입 주차 리텐션: 1·2·4주 뒤 그 주(월~일)에 방문한 인원, 테스트 계정은 기본에서 빠진다")
  void retention_countsReturnsByWeekAfterSignupWeek() {
    List<RetentionCohortCounts> normalOnly = usageAnalyticsQueries.countRetentionCohorts(cohortFrom(), cohortTo(), false);
    List<RetentionCohortCounts> includingAll = usageAnalyticsQueries.countRetentionCohorts(cohortFrom(), cohortTo(), true);

    assertThat(normalOnly).containsExactly(new RetentionCohortCounts(COHORT_WEEK, 3, 1, 1, 1));
    assertThat(includingAll).containsExactly(new RetentionCohortCounts(COHORT_WEEK, 4, 2, 1, 1));
  }

  @Test
  @DisplayName("첫날 한 일별 재방문: 기기 연결 > 카드 체크 > 일과만 > 아무것도 순으로 한 묶음에만, 8일 안 지난 가입자는 대상 아님")
  void firstDayActivation_groupsByFirstDayActionWithSevenDayReturn() {
    // A(첫날 연결, 8일째 방문 = 7일 밖), B(첫날 일과, 15일째 방문), C(예시 일과만 = 아무것도). today 는 가입 주 + 30일, 기록 시작은 가입 주
    Map<String, FirstDayActivationCounts> countsByKind = usageAnalyticsQueries.countFirstDayActivations(
        cohortFrom(), cohortTo(), false, COHORT_WEEK.plusDays(30), COHORT_WEEK).stream()
      .collect(Collectors.toMap(FirstDayActivationCounts::activationKind, count -> count));
    visit(routineOnly, COHORT_WEEK.plusDays(3));
    Map<String, FirstDayActivationCounts> afterVisit = usageAnalyticsQueries.countFirstDayActivations(
        cohortFrom(), cohortTo(), false, COHORT_WEEK.plusDays(30), COHORT_WEEK).stream()
      .collect(Collectors.toMap(FirstDayActivationCounts::activationKind, count -> count));
    List<FirstDayActivationCounts> notMatured = usageAnalyticsQueries.countFirstDayActivations(
      cohortFrom(), cohortTo(), false, COHORT_WEEK.plusDays(5), COHORT_WEEK);

    assertThat(countsByKind).containsOnlyKeys("DEVICE_LINKED", "ROUTINE_MADE", "NOTHING");
    assertThat(countsByKind.get("DEVICE_LINKED")).isEqualTo(new FirstDayActivationCounts("DEVICE_LINKED", 1, 1, 0));
    assertThat(countsByKind.get("ROUTINE_MADE")).isEqualTo(new FirstDayActivationCounts("ROUTINE_MADE", 1, 1, 0));
    assertThat(countsByKind.get("NOTHING")).isEqualTo(new FirstDayActivationCounts("NOTHING", 1, 1, 0));
    assertThat(afterVisit.get("ROUTINE_MADE").retainedCount()).isEqualTo(1);
    assertThat(notMatured).allSatisfy(count -> assertThat(count.maturedCount()).isZero());
  }

  @Test
  @DisplayName("주별 추이: 가입·주간 활성·일과 만듦·카드 체크를 주 첫날(월요일)로 묶고 테스트 계정은 뺀다")
  void weeklyUsage_groupsByMondayWeek() {
    Map<String, Long> totals = usageAnalyticsQueries.countWeeklyUsage(cohortFrom(), COHORT_WEEK.plusDays(35).atStartOfDay(), false)
      .stream()
      .collect(Collectors.toMap(count -> count.seriesKey() + "|" + count.weekStart(), WeeklyCount::total));

    assertThat(totals).containsEntry("SIGNUPS|" + COHORT_WEEK, 3L)
      .containsEntry("ROUTINES_MADE|" + COHORT_WEEK, 2L)
      .containsEntry("CARD_CHECKS|" + COHORT_WEEK, 1L)
      .containsEntry("WEEKLY_ACTIVE|" + COHORT_WEEK.plusDays(7), 1L)
      .containsEntry("WEEKLY_ACTIVE|" + COHORT_WEEK.plusDays(14), 1L)
      .containsEntry("WEEKLY_ACTIVE|" + COHORT_WEEK.plusDays(28), 1L);
  }

  @Test
  @DisplayName("기존 대시보드 가입·방문 숫자도 일반 계정만 센다 (공통 조건 MemberAccountKind.COUNTED_MEMBER_SQL)")
  void memberStats_excludeNonNormalAccounts() {
    Map<String, Long> joinedByDay = memberStatsService
      .countJoinedByBucket(StatsBucketUnit.DAY, COHORT_WEEK, COHORT_WEEK.plusDays(6)).stream()
      .collect(Collectors.toMap(StatsBucketCount::getBucket, StatsBucketCount::getTotal));

    assertThat(joinedByDay).containsEntry(COHORT_WEEK.toString(), 1L).containsEntry(COHORT_WEEK.plusDays(1).toString(), 1L);
    assertThat(memberStatsService.countJoinedOn(COHORT_WEEK)).isEqualTo(1);
    assertThat(memberStatsService.countVisitsOn(COHORT_WEEK.plusDays(8))).isEqualTo(1);
    assertThat(memberStatsService.countVisitsByBucket(StatsBucketUnit.DAY, COHORT_WEEK.plusDays(8), COHORT_WEEK.plusDays(8)))
      .extracting(StatsBucketCount::getTotal).containsExactly(1L);
    assertThat(memberStatsService.countOnline(LocalDateTime.now())).isNotNegative();
  }

  @Test
  @DisplayName("분류 제안 후보: 일반·미확인 계정만 (테스트 계정은 메모가 있어도 후보 아님), 나머지 집계 SQL 도 실제로 돈다")
  void suggestionCandidates_andOtherQueriesRun() {
    List<String> candidateIds = usageAnalyticsQueries.findSuggestionCandidates("%@privaterelay.appleid.com").stream()
      .map(SuggestionCandidate::memberId).toList();

    assertThat(candidateIds).contains(exampleOnly.getId()).doesNotContain(testAccount.getId(), storeBuyer.getId());
    LocalDateTime now = LocalDateTime.now();
    assertThat(usageAnalyticsQueries.countLastActivity(now, false)).isNotNull();
    assertThat(usageAnalyticsQueries.countPlatforms(true)).isNotNull();
    assertThat(usageAnalyticsQueries.countHeadline(LocalDate.now(), now.minusDays(28), now.minusDays(7))).isNotNull();
    assertThat(usageAnalyticsQueries.findRecentSignups(10)).hasSizeLessThanOrEqualTo(10);
    assertThat(usageAnalyticsQueries.findRecentActivities(COHORT_WEEK.atStartOfDay(), 20)).hasSizeLessThanOrEqualTo(20);
  }

  private static LocalDateTime cohortFrom() {
    return COHORT_WEEK.atStartOfDay();
  }

  private static LocalDateTime cohortTo() {
    return COHORT_WEEK.plusDays(7).atStartOfDay();
  }

  // 보호자 + 자기 이룸이, 가입 시각을 joinedAt 으로
  private Member guardianJoinedAt(String suffix, LocalDateTime joinedAt, MemberAccountKind kind, String adminMemo) {
    Member saved = transactionTemplate.execute(status -> {
      Member member = new Member();
      member.setUsername(prefix + suffix);
      member.setPassword("pw");
      member.setStatus(MemberStatus.ACTIVE);
      member.setAccountKind(kind);
      member.setAdminMemo(adminMemo);
      member = memberRepository.save(member);
      Profile profile = profileRepository.save(new Profile());
      ProfileGuardian guardian = new ProfileGuardian();
      guardian.setMember(member);
      guardian.setProfile(profile);
      guardian.setJoinedAt(joinedAt);
      profileGuardianRepository.save(guardian);
      createdProfileIds.add(profile.getId());
      return member;
    });
    createdMemberIds.add(saved.getId());
    jdbcTemplate.update("update member set created_at = :createdAt where id = :id",
      new MapSqlParameterSource("createdAt", joinedAt).addValue("id", saved.getId()));
    return saved;
  }

  // 가입 주에 만든 일과 하나
  private Routine routine(Member member, boolean isExample) {
    Routine saved = transactionTemplate.execute(status -> {
      Routine routine = new Routine();
      routine.setProfile(profileGuardianRepository.findAllWithProfileByMemberIdIn(List.of(member.getId())).get(0).getProfile());
      routine.setCreatedBy(member.getId());
      routine.setRawInputText("it");
      routine.setSanitizedInputText("it");
      routine.setTitle("양치");
      routine.setScheduledAt(COHORT_WEEK.atTime(9, 0));
      routine.setStatus(RoutineStatus.CONFIRMED);
      routine.setIsExample(isExample);
      return routineRepository.save(routine);
    });
    jdbcTemplate.update("update routine set created_at = :createdAt where id = :id",
      new MapSqlParameterSource("createdAt", COHORT_WEEK.atTime(12, 0)).addValue("id", saved.getId()));
    return saved;
  }

  private void completedStep(Routine routine) {
    transactionTemplate.executeWithoutResult(status -> {
      RoutineStep step = new RoutineStep();
      step.setRoutine(routineRepository.findById(routine.getId()).orElseThrow());
      step.setStepOrder(1);
      step.setDescription("이 닦기");
      step.setCompleted(true);
      step.setCompletedAt(COHORT_WEEK.atTime(13, 0));
      routineStepRepository.save(step);
    });
  }

  private void linkDevice(Member member) {
    transactionTemplate.executeWithoutResult(status -> {
      DeviceLink link = new DeviceLink();
      link.setMemberId(member.getId());
      link.setProfileId(createdProfileIds.get(createdMemberIds.indexOf(member.getId())));
      link.setCodeHash(UUID.randomUUID().toString().replace("-", ""));
      link.setExpiresAt(COHORT_WEEK.atTime(14, 0));
      link.setRedeemedAt(COHORT_WEEK.atTime(13, 30));
      deviceLinkRepository.save(link);
    });
  }

  private void storePurchase(Member member) {
    transactionTemplate.executeWithoutResult(status -> {
      Subscription subscription = new Subscription();
      subscription.setMember(memberRepository.findById(member.getId()).orElseThrow());
      subscription.setPlan(PlanType.PRO);
      subscription.setSource(SubscriptionSource.APPLE_IAP);
      subscription.setStartedAt(COHORT_WEEK.atTime(15, 0));
      subscriptionRepository.save(subscription);
    });
  }

  private void visit(Member member, LocalDate visitDate) {
    transactionTemplate.executeWithoutResult(status ->
      memberDailyVisitRepository.insertIfAbsent(UUID.randomUUID().toString(), member.getId(), visitDate));
  }
}
