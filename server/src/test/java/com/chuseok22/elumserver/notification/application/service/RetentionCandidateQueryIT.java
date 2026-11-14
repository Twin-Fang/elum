package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import jakarta.persistence.EntityManager;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 리텐션 자동 알림 4종(#1409) 받을 사람 쿼리를 실제 Postgres 로 검증. 평소 빌드에서는 건너뜀
 * 목 테스트로는 JPQL(not exists, 날짜 경계, 기기 연결 조인)이 실제로 맞는지 못 봄. 표는 ddl-auto: update 가 만듦
 *
 * <pre>
 * createdb elum_it_1409
 * ELUM_IT_DB_URL=jdbc:postgresql://localhost:5432/elum_it_1409 ELUM_IT_DB_USERNAME=me ELUM_IT_DB_PASSWORD= \
 *   ./gradlew test --tests '*RetentionCandidateQueryIT'
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
class RetentionCandidateQueryIT {

  @Autowired private AutoNotificationCandidateFinder candidateFinder;
  @Autowired private MemberRepository memberRepository;
  @Autowired private ProfileRepository profileRepository;
  @Autowired private ProfileGuardianRepository profileGuardianRepository;
  @Autowired private RoutineRepository routineRepository;
  @Autowired private RoutineStepRepository routineStepRepository;
  @Autowired private DeviceLinkRepository deviceLinkRepository;
  @Autowired private EntityManager entityManager;
  @Autowired private TransactionTemplate transactionTemplate;

  private final String prefix = "it1409_" + UUID.randomUUID().toString().substring(0, 8) + "_";
  private final LocalDate today = LocalDate.now();
  private final LocalDateTime noon = today.atTime(12, 0);
  private final List<String> createdMemberIds = new ArrayList<>();
  private final List<String> createdProfileIds = new ArrayList<>();

  @AfterEach
  void cleanUp() {
    transactionTemplate.executeWithoutResult(status -> {
      routineRepository.findAll().stream()
        .filter(routine -> createdProfileIds.contains(routine.getProfile().getId()))
        .forEach(routine -> {
          routineStepRepository.findAll().stream()
            .filter(step -> step.getRoutine().getId().equals(routine.getId()))
            .forEach(routineStepRepository::delete);
          routineRepository.delete(routine);
        });
      createdProfileIds.forEach(profileId -> deviceLinkRepository.deleteAll(deviceLinkRepository.findAllByProfileId(profileId)));
      profileGuardianRepository.findAll().stream()
        .filter(guardian -> createdMemberIds.contains(guardian.getMember().getId()))
        .forEach(profileGuardianRepository::delete);
      createdProfileIds.forEach(profileRepository::deleteById);
      createdMemberIds.forEach(memberRepository::deleteById);
    });
  }

  @Test
  @DisplayName("첫 일과 만들기 안내: 이름을 저장한 가입 1일째·3일째 보호자 중 일과를 안 만든 사람만")
  void onboardedNoRoutine_picksDay1AndDay3WithoutRoutine() {
    Member day1 = guardianJoinedDaysAgo("d1", 1, "하늘");
    Member day3 = guardianJoinedDaysAgo("d3", 3, "바다");
    guardianJoinedDaysAgo("d2", 2, "숲");
    guardianJoinedDaysAgo("noname", 1, null);
    Member creator = guardianJoinedDaysAgo("creator", 1, "별");
    routine(creator, profileOf(creator), RoutineStatus.PENDING_REVIEW, today.atTime(9, 0), null);

    assertThat(myMemberIds(AutoNotificationType.ONBOARDED_NO_ROUTINE))
      .containsExactlyInAnyOrder(day1.getId(), day3.getId());
  }

  @Test
  @DisplayName("보낸 일과 시작 전: 오늘 보냈고 기기 연결됐는데 오늘 카드·일과를 하나도 안 마친 보호자만")
  void sentNotDone_needsLinkedDeviceAndNoProgressToday() {
    Member waiting = guardianJoinedDaysAgo("waiting", 10, "하늘");
    routine(waiting, profileOf(waiting), RoutineStatus.CONFIRMED, today.atTime(9, 0), null);
    link(profileOf(waiting), waiting, true);

    Member started = guardianJoinedDaysAgo("started", 10, "바다");
    Routine startedRoutine = routine(started, profileOf(started), RoutineStatus.CONFIRMED, today.atTime(9, 0), null);
    link(profileOf(started), started, true);
    completedStep(startedRoutine, today.atTime(9, 30));

    Member unlinked = guardianJoinedDaysAgo("unlinked", 10, "숲");
    routine(unlinked, profileOf(unlinked), RoutineStatus.CONFIRMED, today.atTime(9, 0), null);
    link(profileOf(unlinked), unlinked, false);

    assertThat(myMemberIds(AutoNotificationType.SENT_NOT_DONE)).containsExactly(waiting.getId());
  }

  @Test
  @DisplayName("연속 기록 이어 가기: 어제까지 2일 이상 이어졌고 오늘 아직이면 그 이룸이 보호자에게")
  void streakAtRisk_needsTwoDaysUntilYesterdayAndNothingToday() {
    Member twoDays = guardianJoinedDaysAgo("streak2", 10, "하늘");
    completedRoutine(twoDays, 1);
    completedRoutine(twoDays, 2);

    Member oneDay = guardianJoinedDaysAgo("streak1", 10, "바다");
    completedRoutine(oneDay, 1);

    Member doneToday = guardianJoinedDaysAgo("today", 10, "숲");
    completedRoutine(doneToday, 0);
    completedRoutine(doneToday, 1);
    completedRoutine(doneToday, 2);

    List<AutoNotificationCandidate> candidates = myCandidates(AutoNotificationType.STREAK_AT_RISK);
    assertThat(candidates).extracting(AutoNotificationCandidate::memberId).containsExactly(twoDays.getId());
    assertThat(candidates.get(0).childName()).isEqualTo("하늘");
  }

  @Test
  @DisplayName("기기 연결 안내: 처음 보낸 일과가 1~3일 전이고 기기 연결도, 마친 일과도 없는 보호자만")
  void linkPending_firstSendWithinWindowWithoutLinkOrCompletion() {
    Member pending = guardianJoinedDaysAgo("pending", 10, "하늘");
    backdateRoutine(routine(pending, profileOf(pending), RoutineStatus.CONFIRMED, today.minusDays(2).atTime(9, 0), null), 2);

    Member linked = guardianJoinedDaysAgo("linked", 10, "바다");
    backdateRoutine(routine(linked, profileOf(linked), RoutineStatus.CONFIRMED, today.minusDays(2).atTime(9, 0), null), 2);
    link(profileOf(linked), linked, true);

    Member old = guardianJoinedDaysAgo("old", 10, "숲");
    backdateRoutine(routine(old, profileOf(old), RoutineStatus.CONFIRMED, today.minusDays(5).atTime(9, 0), null), 5);
    backdateRoutine(routine(old, profileOf(old), RoutineStatus.CONFIRMED, today.minusDays(2).atTime(9, 0), null), 2);

    Member sameDevice = guardianJoinedDaysAgo("samedevice", 10, "별");
    backdateRoutine(routine(sameDevice, profileOf(sameDevice), RoutineStatus.COMPLETED, today.minusDays(2).atTime(9, 0),
      today.minusDays(2).atTime(10, 0)), 2);

    assertThat(myMemberIds(AutoNotificationType.LINK_PENDING)).containsExactly(pending.getId());
  }

  private List<String> myMemberIds(AutoNotificationType type) {
    return myCandidates(type).stream().map(AutoNotificationCandidate::memberId).toList();
  }

  private List<AutoNotificationCandidate> myCandidates(AutoNotificationType type) {
    return candidateFinder.find(type, noon).stream()
      .filter(candidate -> createdMemberIds.contains(candidate.memberId()))
      .toList();
  }

  // 보호자 + 자기 이룸이 (이름이 null 이면 온보딩 전), 가입 시각을 그날 정오로
  private Member guardianJoinedDaysAgo(String suffix, int daysAgo, String profileNickname) {
    return transactionTemplate.execute(status -> {
      Member member = new Member();
      member.setUsername(prefix + suffix);
      member.setPassword("pw");
      member.setStatus(MemberStatus.ACTIVE);
      member = memberRepository.save(member);
      Profile profile = new Profile();
      profile.setNickname(profileNickname);
      profile = profileRepository.save(profile);
      ProfileGuardian guardian = new ProfileGuardian();
      guardian.setMember(member);
      guardian.setProfile(profile);
      guardian.setJoinedAt(LocalDateTime.now());
      profileGuardianRepository.save(guardian);
      entityManager.flush();
      entityManager.createNativeQuery("update member set created_at = :createdAt where id = :id")
        .setParameter("createdAt", today.minusDays(daysAgo).atTime(12, 0))
        .setParameter("id", member.getId())
        .executeUpdate();
      createdMemberIds.add(member.getId());
      createdProfileIds.add(profile.getId());
      return member;
    });
  }

  private Profile profileOf(Member member) {
    return transactionTemplate.execute(status -> profileGuardianRepository.findAllWithProfileByMemberIdIn(
      List.of(member.getId())).get(0).getProfile());
  }

  private Routine routine(Member member, Profile profile, RoutineStatus status, LocalDateTime scheduledAt,
    LocalDateTime completedAt) {
    return transactionTemplate.execute(transactionStatus -> {
      Routine routine = new Routine();
      routine.setProfile(profile);
      routine.setCreatedBy(member.getId());
      routine.setRawInputText("it");
      routine.setSanitizedInputText("it");
      routine.setTitle("양치");
      routine.setScheduledAt(scheduledAt);
      routine.setStatus(status);
      routine.setCompletedAt(completedAt);
      return routineRepository.save(routine);
    });
  }

  // 그날(daysAgo 일 전) 마친 일과 하나
  private void completedRoutine(Member member, int daysAgo) {
    LocalDateTime day = today.minusDays(daysAgo).atTime(daysAgo == 0 ? 9 : 10, 0);
    routine(member, profileOf(member), RoutineStatus.COMPLETED, day, day.plusMinutes(10));
  }

  private void completedStep(Routine routine, LocalDateTime completedAt) {
    transactionTemplate.executeWithoutResult(status -> {
      RoutineStep step = new RoutineStep();
      step.setRoutine(routineRepository.findById(routine.getId()).orElseThrow());
      step.setStepOrder(1);
      step.setDescription("이 닦기");
      step.setCompleted(true);
      step.setCompletedAt(completedAt);
      routineStepRepository.save(step);
    });
  }

  private void backdateRoutine(Routine routine, int daysAgo) {
    transactionTemplate.executeWithoutResult(status -> entityManager
      .createNativeQuery("update routine set created_at = :createdAt where id = :id")
      .setParameter("createdAt", today.minusDays(daysAgo).atTime(9, 0))
      .setParameter("id", routine.getId())
      .executeUpdate());
  }

  // isRedeemed: true 면 연결된 기기, false 면 발급만 하고 안 쓴 암호
  private void link(Profile profile, Member member, boolean isRedeemed) {
    transactionTemplate.executeWithoutResult(status -> {
      DeviceLink link = new DeviceLink();
      link.setMemberId(member.getId());
      link.setProfileId(profile.getId());
      link.setCodeHash(UUID.randomUUID().toString().replace("-", ""));
      link.setExpiresAt(LocalDateTime.now().plusMinutes(10));
      link.setRedeemedAt(isRedeemed ? LocalDateTime.now().minusDays(1) : null);
      deviceLinkRepository.save(link);
    });
  }
}
