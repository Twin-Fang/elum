package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.RoutinePersonalization;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.routine.core.RoutineCardText;
import com.chuseok22.elumserver.routine.core.RoutineMemoryLine;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemory;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 일과 만들기 맞춤 계획 (#1082). 깨지면 Free 에도 메모가 들어가거나, 끈 메모가 계속 쓰이거나, 메모 조회 실패로 일과 만들기가 멈춘다
 */
@ExtendWith(MockitoExtension.class)
class RoutinePersonalizationProviderTest {

  private static final String MEMBER_ID = "member-1";
  private static final String PROFILE_ID = "profile-1";

  @Mock private EntitlementService entitlementService;
  @Mock private RoutineMemoryRepository routineMemoryRepository;
  @Mock private RoutineRepository routineRepository;
  @InjectMocks private RoutinePersonalizationProvider provider;

  @Test
  @DisplayName("Free: 메모·예시를 조회하지 않고 지금 하네스 그대로 (스냅샷도 남기지 않음)")
  void free_isInactive() {
    when(entitlementService.isAllowed(MEMBER_ID, Entitlement.ROUTINE_MEMORY)).thenReturn(false);

    RoutinePersonalizationProvider.Plan plan = provider.planFor(MEMBER_ID, PROFILE_ID, "하늘이", AppLocale.KO);

    assertThat(plan.isMemoryActive()).isFalse();
    assertThat(plan.personalization()).isNull();
    verify(routineRepository, never()).findTop10ByProfileIdAndAiDraftCardsIsNotNullAndStatusInOrderByCreatedAtDesc(any(), any());
  }

  @Test
  @DisplayName("Pro 라도 보호자가 끄면 넣지 않는다")
  void proDisabled_isInactive() {
    when(entitlementService.isAllowed(MEMBER_ID, Entitlement.ROUTINE_MEMORY)).thenReturn(true);
    RoutineMemory memory = new RoutineMemory();
    memory.setEnabled(false);
    when(routineMemoryRepository.findByProfileId(PROFILE_ID)).thenReturn(Optional.of(memory));

    assertThat(provider.planFor(MEMBER_ID, PROFILE_ID, "하늘이", AppLocale.KO).isMemoryActive()).isFalse();
  }

  @Test
  @DisplayName("Pro + 켜짐: 메모 줄과 고친 예시(먼저)를 싣고, 이름은 자리표시로 바꾼다")
  void proEnabled_carriesNotesAndEditedExamplesFirst() {
    when(entitlementService.isAllowed(MEMBER_ID, Entitlement.ROUTINE_MEMORY)).thenReturn(true);
    RoutineMemory memory = new RoutineMemory();
    memory.setLines(RoutineMemoryJson.writeLines(List.of(
      new RoutineMemoryLine("하늘이 카드는 잘게 나눠요", RoutineMemoryLine.Source.AI))));
    when(routineMemoryRepository.findByProfileId(PROFILE_ID)).thenReturn(Optional.of(memory));
    Routine unedited = routine("하늘이 양치", List.of(new RoutineCardText("이를 닦아요", "칫솔로 닦아요")),
      List.of(new RoutineCardText("이를 닦아요", "칫솔로 닦아요")));
    Routine edited = routine("손 씻기", List.of(new RoutineCardText("손을 씻어요", "비누로 씻어요")),
      List.of(new RoutineCardText("손을 닦아요", "비누로 닦아요")));
    when(routineRepository.findTop10ByProfileIdAndAiDraftCardsIsNotNullAndStatusInOrderByCreatedAtDesc(eq(PROFILE_ID), any()))
      .thenReturn(List.of(unedited, edited));

    RoutinePersonalizationProvider.Plan plan = provider.planFor(MEMBER_ID, PROFILE_ID, "하늘이", AppLocale.KO);

    assertThat(plan.isMemoryActive()).isTrue();
    RoutinePersonalization personalization = plan.personalization();
    assertThat(personalization.memoryNotes()).containsExactly("이룸이 카드는 잘게 나눠요");
    assertThat(personalization.confirmedExamples()).extracting(RoutinePersonalization.ConfirmedExample::title)
      .containsExactly("손 씻기", "이룸이 양치");
    assertThat(personalization.confirmedExamples().get(0).cards()).containsExactly("손을 닦아요 / 비누로 닦아요");
    assertThat(personalization.instruction()).isEqualTo(RoutinePersonalization.INSTRUCTION);
  }

  @Test
  @DisplayName("메모 조회가 실패해도 던지지 않고 지금 하네스 그대로 (일과 만들기를 막지 않음)")
  void lookupFailure_failsOpen() {
    when(entitlementService.isAllowed(MEMBER_ID, Entitlement.ROUTINE_MEMORY)).thenReturn(true);
    when(routineMemoryRepository.findByProfileId(PROFILE_ID)).thenThrow(new IllegalStateException("db down"));

    RoutinePersonalizationProvider.Plan plan = provider.planFor(MEMBER_ID, PROFILE_ID, "하늘이", AppLocale.KO);

    assertThat(plan.isMemoryActive()).isFalse();
    assertThat(plan.personalization()).isNull();
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
