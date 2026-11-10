package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.RoutinePersonalization;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.routine.core.RoutineCardText;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleSource;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleType;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRule;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRuleRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 일과 만들기 맞춤 계획: 깨지면 남의 규칙·관찰 중 규칙이 일과에 들어가거나, 끈 메모리가 계속 쓰이거나, 조회 실패로 일과 만들기가 멈춘다
 */
@ExtendWith(MockitoExtension.class)
class RoutinePersonalizationProviderTest {

  private static final String MEMBER_A = "member-a";
  private static final String MEMBER_B = "member-b";
  private static final String PROFILE_ID = "profile-1";

  @Mock private EntitlementService entitlementService;
  @Mock private RoutineMemorySettings routineMemorySettings;
  @Mock private RoutineMemoryRuleRepository routineMemoryRuleRepository;
  @Mock private RoutineRepository routineRepository;
  @InjectMocks private RoutinePersonalizationProvider provider;

  private void givenProAndEnabled(String memberId) {
    when(entitlementService.isAllowed(memberId, Entitlement.ROUTINE_MEMORY)).thenReturn(true);
    when(routineMemorySettings.isEnabled(PROFILE_ID, memberId)).thenReturn(true);
  }

  private void givenActiveRules(String memberId, RoutineMemoryRule... rules) {
    when(routineMemoryRuleRepository.findAllByProfileIdAndMemberIdAndStatus(
      PROFILE_ID, memberId, RoutineMemoryRuleStatus.ACTIVE)).thenReturn(List.of(rules));
  }

  @Test
  @DisplayName("Free: 규칙·예시를 조회하지 않고 지금 하네스 그대로 (처음 카드 사본도 남기지 않음)")
  void free_isInactive() {
    when(entitlementService.isAllowed(MEMBER_A, Entitlement.ROUTINE_MEMORY)).thenReturn(false);

    RoutinePersonalizationProvider.Plan plan = provider.planFor(MEMBER_A, PROFILE_ID, "하늘이", AppLocale.KO);

    assertThat(plan.isMemoryActive()).isFalse();
    assertThat(plan.personalization()).isNull();
    assertThat(plan.appliedRuleCount()).isZero();
    verify(routineMemoryRuleRepository, never()).findAllByProfileIdAndMemberIdAndStatus(any(), any(), any());
  }

  @Test
  @DisplayName("보호자가 끄면 규칙이 있어도 넣지 않고 조회도 하지 않는다 — 끈 메모리가 계속 쓰인다")
  void disabled_isInactiveAndLooksUpNothing() {
    when(entitlementService.isAllowed(MEMBER_A, Entitlement.ROUTINE_MEMORY)).thenReturn(true);
    when(routineMemorySettings.isEnabled(PROFILE_ID, MEMBER_A)).thenReturn(false);

    RoutinePersonalizationProvider.Plan plan = provider.planFor(MEMBER_A, PROFILE_ID, "하늘이", AppLocale.KO);

    assertThat(plan.isMemoryActive()).isFalse();
    verify(routineMemoryRuleRepository, never()).findAllByProfileIdAndMemberIdAndStatus(any(), any(), any());
  }

  @Test
  @DisplayName("보호자 A 의 규칙은 보호자 B 의 일과 생성에 들어가지 않는다 — 남의 취향이 내 일과에 섞인다")
  void guardianBDoesNotGetGuardianAsRules() {
    givenProAndEnabled(MEMBER_B);
    givenActiveRules(MEMBER_B);
    when(routineRepository.findTop10ByProfileIdAndCreatedByAndAiDraftCardsIsNotNullAndStatusInOrderByCreatedAtDesc(
      eq(PROFILE_ID), eq(MEMBER_B), any())).thenReturn(List.of());

    RoutinePersonalizationProvider.Plan plan = provider.planFor(MEMBER_B, PROFILE_ID, "하늘이", AppLocale.KO);

    assertThat(plan.isMemoryActive()).isTrue();
    assertThat(plan.personalization()).isNull();
    assertThat(plan.appliedRuleCount()).isZero();
    verify(routineMemoryRuleRepository, never()).findAllByProfileIdAndMemberIdAndStatus(any(), eq(MEMBER_A), any());
    verify(routineRepository, never())
      .findTop10ByProfileIdAndCreatedByAndAiDraftCardsIsNotNullAndStatusInOrderByCreatedAtDesc(any(), eq(MEMBER_A), any());
  }

  @Test
  @DisplayName("적용 중(ACTIVE) 규칙만 조회한다 — 관찰 중 규칙이 한 번 고쳤다고 일과에 들어간다")
  void onlyActiveRulesAreRequested() {
    givenProAndEnabled(MEMBER_A);
    givenActiveRules(MEMBER_A, rule("착용해요 대신 입어요", RoutineMemoryRuleSource.AI, 3));
    when(routineRepository.findTop10ByProfileIdAndCreatedByAndAiDraftCardsIsNotNullAndStatusInOrderByCreatedAtDesc(
      anyString(), anyString(), any())).thenReturn(List.of());

    provider.planFor(MEMBER_A, PROFILE_ID, "하늘이", AppLocale.KO);

    verify(routineMemoryRuleRepository).findAllByProfileIdAndMemberIdAndStatus(
      PROFILE_ID, MEMBER_A, RoutineMemoryRuleStatus.ACTIVE);
    verify(routineMemoryRuleRepository, never()).findAllByProfileIdAndMemberIdAndStatus(
      any(), any(), eq(RoutineMemoryRuleStatus.WATCHING));
  }

  @Test
  @DisplayName("규칙은 직접 적은 것 먼저, 그다음 근거 많은 순으로 최대 10개만 넣고 이름은 자리표시로 바꾼다")
  void rulesAreOrderedLimitedAndMasked() {
    givenProAndEnabled(MEMBER_A);
    List<RoutineMemoryRule> rules = new ArrayList<>();
    for (int index = 0; index < 11; index++) {
      rules.add(rule("AI 규칙 " + index, RoutineMemoryRuleSource.AI, index));
    }
    rules.add(rule("하늘이 카드는 10자 안으로", RoutineMemoryRuleSource.MANUAL, 0));
    when(routineMemoryRuleRepository.findAllByProfileIdAndMemberIdAndStatus(
      PROFILE_ID, MEMBER_A, RoutineMemoryRuleStatus.ACTIVE)).thenReturn(rules);
    when(routineRepository.findTop10ByProfileIdAndCreatedByAndAiDraftCardsIsNotNullAndStatusInOrderByCreatedAtDesc(
      anyString(), anyString(), any())).thenReturn(List.of());

    RoutinePersonalizationProvider.Plan plan = provider.planFor(MEMBER_A, PROFILE_ID, "하늘이", AppLocale.KO);

    List<String> notes = plan.personalization().memoryNotes();
    assertThat(notes).hasSize(10);
    assertThat(notes.get(0)).isEqualTo("이룸이 카드는 10자 안으로");
    assertThat(notes.get(1)).isEqualTo("AI 규칙 10");
    assertThat(plan.appliedRuleCount()).isEqualTo(10);
  }

  @Test
  @DisplayName("예시는 그 보호자가 고쳐 확정한 일과만 쓴다 — 고치지 않은 일과를 예시로 채우지 않는다")
  void examplesAreOnlyEditedByThatGuardian() {
    givenProAndEnabled(MEMBER_A);
    givenActiveRules(MEMBER_A);
    Routine unedited = routine("하늘이 양치", List.of(new RoutineCardText("이를 닦아요", "칫솔로 닦아요")),
      List.of(new RoutineCardText("이를 닦아요", "칫솔로 닦아요")));
    Routine edited = routine("손 씻기", List.of(new RoutineCardText("손을 씻어요", "비누로 씻어요")),
      List.of(new RoutineCardText("손을 닦아요", "비누로 닦아요")));
    when(routineRepository.findTop10ByProfileIdAndCreatedByAndAiDraftCardsIsNotNullAndStatusInOrderByCreatedAtDesc(
      eq(PROFILE_ID), eq(MEMBER_A), any())).thenReturn(List.of(unedited, edited));

    RoutinePersonalizationProvider.Plan plan = provider.planFor(MEMBER_A, PROFILE_ID, "하늘이", AppLocale.KO);

    RoutinePersonalization personalization = plan.personalization();
    assertThat(personalization.confirmedExamples()).extracting(RoutinePersonalization.ConfirmedExample::title)
      .containsExactly("손 씻기");
    assertThat(personalization.confirmedExamples().get(0).cards()).containsExactly("손을 닦아요 / 비누로 닦아요");
    assertThat(personalization.instruction()).isEqualTo(RoutinePersonalization.INSTRUCTION);
  }

  @Test
  @DisplayName("규칙 조회가 실패해도 던지지 않고 지금 하네스 그대로 (일과 만들기를 막지 않음)")
  void lookupFailure_failsOpen() {
    givenProAndEnabled(MEMBER_A);
    when(routineMemoryRuleRepository.findAllByProfileIdAndMemberIdAndStatus(any(), any(), any()))
      .thenThrow(new IllegalStateException("db down"));

    RoutinePersonalizationProvider.Plan plan = provider.planFor(MEMBER_A, PROFILE_ID, "하늘이", AppLocale.KO);

    assertThat(plan.isMemoryActive()).isFalse();
    assertThat(plan.personalization()).isNull();
  }

  private static RoutineMemoryRule rule(String summary, RoutineMemoryRuleSource source, int evidenceCount) {
    RoutineMemoryRule rule = new RoutineMemoryRule();
    rule.setType(source == RoutineMemoryRuleSource.MANUAL ? RoutineMemoryRuleType.MANUAL : RoutineMemoryRuleType.WORD);
    rule.setStatus(RoutineMemoryRuleStatus.ACTIVE);
    rule.setSource(source);
    rule.setSummary(summary);
    rule.setEvidenceCount(evidenceCount);
    return rule;
  }

  static Routine routine(String title, List<RoutineCardText> aiCards, List<RoutineCardText> confirmedCards) {
    Routine routine = new Routine();
    routine.setTitle(title);
    routine.setAiDraftCards(RoutineMemoryJson.writeCards(aiCards));
    List<RoutineStep> steps = new ArrayList<>();
    for (int index = 0; index < confirmedCards.size(); index++) {
      RoutineStep step = new RoutineStep();
      step.setStepOrder(index + 1);
      step.setTitle(confirmedCards.get(index).title());
      step.setDescription(confirmedCards.get(index).description());
      steps.add(step);
    }
    routine.setSteps(steps);
    return routine;
  }
}
