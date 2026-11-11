package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.RoutinePersonalization;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.credit.application.service.CreditQueryService;
import com.chuseok22.elumserver.credit.application.service.CreditReservation;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.core.RoutineCardText;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineAiPipeline;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineRequestCooldownGuard;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.systemconfig.application.service.EnabledLocales;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 일과 만들기의 AI 메모 연결 (#1082). 깨지면 Free 에도 메모가 들어가거나, Pro 의 첫 카드가 기록되지 않아 배우지 못하거나,
 * 맞춤 정보가 다음 요청에 새어 남의 이룸이 메모가 들어간다
 */
@ExtendWith(MockitoExtension.class)
class RoutineCreateServiceMemoryTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");
  private static final RoutineCreateRequest REQUEST = new RoutineCreateRequest("손 씻기", null, null, null, null);
  private static final RoutinePersonalization PERSONALIZATION = RoutinePersonalization.of(
    List.of("'손을 씻어요' 대신 '손을 닦아요'라고 써요"), List.of());

  @Mock private RoutineAiPipeline routineAiPipeline;
  @Mock private RoutineImageStorage routineImageStorage;
  @Mock private RoutineRequestCooldownGuard routineRequestCooldownGuard;
  @Mock private RoutineQuotaGuard routineQuotaGuard;
  @Mock private AiDailyBudgetGuard aiDailyBudgetGuard;
  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private RoutineCreationWriter routineCreationWriter;
  @Mock private CreditReservationService creditReservationService;
  @Mock private CreditQueryService creditQueryService;
  @Mock private EnabledLocales enabledLocales;
  @Mock private RoutinePersonalizationProvider routinePersonalizationProvider;
  // 목 기본 false = 그림을 그리는 요금제 (기존 시험 동작 그대로)
  @Mock private RoutineAiPicturePolicy routineAiPicturePolicy;

  @InjectMocks private RoutineCreateService routineCreateService;

  private final AtomicReference<RoutinePersonalization> seenByAi = new AtomicReference<>();

  @BeforeEach
  void setUp() {
    when(enabledLocales.resolveContentLocale(any())).thenReturn(AppLocale.KO);
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setNickname("하늘이");
    profile.setCharacter(CharacterType.LULU);
    profile.setSupportGoals(Set.of());
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    when(creditReservationService.reserve(any(), any(), any(), eq(true))).thenReturn(CreditReservation.disabled());
    when(routineAiPipeline.generateForCreate(any(), any(), any(), any(), any(), any(), any())).thenAnswer(invocation -> {
      seenByAi.set(AiCallContext.currentRoutinePersonalization());
      return new RoutineAiPipeline.RoutineGenerationResult("손 닦기", List.of(
        new RoutineAiPipeline.GeneratedStep(1, "손을 닦아요", "비누로 손을 닦아요", null)), "batch-1");
    });
    when(routineCreationWriter.save(any(), any(), any(Routine.class), any(), any(Integer.class)))
      .thenAnswer(i -> new RoutineCreationWriter.SavedRoutine(i.getArgument(2), null));
  }

  @AfterEach
  void tearDown() {
    AiCallContext.clear();
  }

  private Routine savedRoutine() {
    ArgumentCaptor<Routine> saved = ArgumentCaptor.forClass(Routine.class);
    verify(routineCreationWriter).save(any(), any(), saved.capture(), any(), any(Integer.class));
    return saved.getValue();
  }

  @Test
  @DisplayName("Pro + 켜짐: AI 호출에 규칙이 실리고, AI 처음 카드 글을 사본으로 남기며, 응답에 넣은 규칙 수가 오고, 끝나면 맥락을 비운다")
  void activePlan_carriesMemoryAndStoresDraft() {
    when(routinePersonalizationProvider.planFor("member-1", "profile-1", "하늘이", AppLocale.KO))
      .thenReturn(new RoutinePersonalizationProvider.Plan(true, PERSONALIZATION, 1));

    RoutineResponse response = routineCreateService.create(GUARDIAN, REQUEST, "key-1");

    assertThat(response.appliedMemoryRuleCount()).isEqualTo(1);
    assertThat(seenByAi.get()).isEqualTo(PERSONALIZATION);
    assertThat(RoutineMemoryJson.readCards(savedRoutine().getAiDraftCards()))
      .containsExactly(new RoutineCardText("손을 닦아요", "비누로 손을 닦아요"));
    assertThat(AiCallContext.currentRoutinePersonalization()).isNull();
  }

  @Test
  @DisplayName("Free·꺼짐·조회 실패(빈 계획): 메모 없이 지금 하네스로 만들고 스냅샷도 남기지 않는다")
  void inactivePlan_keepsHarnessAndNoDraft() {
    when(routinePersonalizationProvider.planFor(any(), any(), any(), any()))
      .thenReturn(RoutinePersonalizationProvider.Plan.INACTIVE);

    routineCreateService.create(GUARDIAN, REQUEST, "key-1");

    assertThat(seenByAi.get()).isNull();
    assertThat(savedRoutine().getAiDraftCards()).isNull();
  }
}
