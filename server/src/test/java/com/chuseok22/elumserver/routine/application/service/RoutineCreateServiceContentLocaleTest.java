package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.credit.application.service.CreditReservation;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.credit.application.service.CreditSettlement;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineAiPipeline;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineRequestCooldownGuard;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.systemconfig.application.service.EnabledLocales;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/** 일과 만들기·추가 질문이 일과 언어를 AI 호출에 싣고, 끝나면 비운다. AI 는 부르지 않는다(파이프라인은 목). */
@ExtendWith(MockitoExtension.class)
class RoutineCreateServiceContentLocaleTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");

  @Mock private RoutineAiPipeline routineAiPipeline;
  @Mock private RoutineImageStorage routineImageStorage;
  @Mock private RoutineRequestCooldownGuard routineRequestCooldownGuard;
  @Mock private RoutineQuotaGuard routineQuotaGuard;
  @Mock private AiDailyBudgetGuard aiDailyBudgetGuard;
  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private RoutineCreationWriter routineCreationWriter;
  @Mock private CreditReservationService creditReservationService;
  @Mock private com.chuseok22.elumserver.credit.application.service.CreditQueryService creditQueryService;
  @Mock private EnabledLocales enabledLocales;

  @InjectMocks private RoutineCreateService routineCreateService;

  @AfterEach
  void tearDown() {
    AiCallContext.clear();
  }

  private void givenProfile(Set<SupportGoal> goals) {
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setNickname("Haneul");
    profile.setCharacter(CharacterType.LULU);
    profile.setSupportGoals(goals);
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
  }

  @Test
  @DisplayName("일과 만들기: AI 가 불리는 순간 일과 언어가 실려 있고, 저장되는 routine.language 가 같은 값이며, 끝나면 비워진다")
  void create_carriesTheSameLocaleToAiAndToTheSavedRoutine() {
    when(enabledLocales.resolveContentLocale(any())).thenReturn(AppLocale.ES);
    givenProfile(Set.of());
    when(creditReservationService.reserve("member-1", CreditJobKind.ROUTINE_CREATE, "key-1", true))
      .thenReturn(CreditReservation.reserved("job-1"));
    AtomicReference<AppLocale> seenByAi = new AtomicReference<>();
    when(routineAiPipeline.generateForCreate(any(), any(), any(), any(), any(), any(), any())).thenAnswer(invocation -> {
      seenByAi.set(AiCallContext.currentContentLocale());
      return new RoutineAiPipeline.RoutineGenerationResult("Ir al colegio", List.of(
        new RoutineAiPipeline.GeneratedStep(1, "Ponte la ropa", "Ponte la ropa", "img/b/1.png")), "batch-1");
    });
    when(routineCreationWriter.save(eq("member-1"), eq("profile-1"), any(Routine.class), eq("job-1"), eq(1)))
      .thenAnswer(i -> new RoutineCreationWriter.SavedRoutine(i.getArgument(2), new CreditSettlement(3, 0, 97)));

    routineCreateService.create(GUARDIAN, new RoutineCreateRequest("Ir al colegio", null, null, null, null), "key-1");

    assertThat(seenByAi.get()).isEqualTo(AppLocale.ES);
    ArgumentCaptor<Routine> saved = ArgumentCaptor.forClass(Routine.class);
    verify(routineCreationWriter).save(eq("member-1"), eq("profile-1"), saved.capture(), eq("job-1"), eq(1));
    assertThat(saved.getValue().getLanguage()).isEqualTo(AppLocale.ES);
    assertThat(AiCallContext.currentContentLocale()).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("일과 만들기: AI 가 던져도 일과 언어는 비워진다 — 다음 요청에 새지 않는다")
  void create_aiFailureStillClearsLocale() {
    when(enabledLocales.resolveContentLocale(any())).thenReturn(AppLocale.JA);
    givenProfile(Set.of());
    when(creditReservationService.reserve(any(), any(), any(), eq(true))).thenReturn(CreditReservation.reserved("job-1"));
    when(routineAiPipeline.generateForCreate(any(), any(), any(), any(), any(), any(), any()))
      .thenThrow(new IllegalStateException("AI down"));

    assertThatThrownBy(() -> routineCreateService.create(
      GUARDIAN, new RoutineCreateRequest("明日", null, null, null, null), "key-1"))
      .isInstanceOf(IllegalStateException.class);

    assertThat(AiCallContext.currentContentLocale()).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("추가 질문: AI 가 불리는 순간 일과 언어가 실려 있고 끝나면 비워진다")
  void generateQuestion_carriesLocale() {
    when(enabledLocales.resolveContentLocale(any())).thenReturn(AppLocale.JA);
    givenProfile(Set.of(SupportGoal.PREPARE_ITEMS));
    AtomicReference<AppLocale> seenByAi = new AtomicReference<>();
    when(routineAiPipeline.generateQuestion(any(), any(), any())).thenAnswer(invocation -> {
      seenByAi.set(AiCallContext.currentContentLocale());
      return new RoutineAiPipeline.RoutineQuestionResult(List.of());
    });

    routineCreateService.generateQuestion(GUARDIAN, new RoutineQuestionRequest("明日、学校に行く"));

    assertThat(seenByAi.get()).isEqualTo(AppLocale.JA);
    assertThat(AiCallContext.currentContentLocale()).isEqualTo(AppLocale.KO);
  }
}
