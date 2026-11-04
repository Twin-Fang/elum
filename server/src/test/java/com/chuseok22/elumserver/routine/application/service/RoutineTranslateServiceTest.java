package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.RoutineTranslationDraft;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.credit.application.service.CreditReservation;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.credit.application.service.CreditSettlement;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineTranslationAi;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.transaction.PlatformTransactionManager;

/// 다른 언어로 만들기 (#1077): Free 거절, 번역 사본(그림 재사용·일과관리 원본), 실패 시 사본 없음·크레딧 반환
class RoutineTranslateServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");

  private final RoutineRepository routineRepository = mock(RoutineRepository.class);
  private final ProfileAccessGuard profileAccessGuard = mock(ProfileAccessGuard.class);
  private final EntitlementService entitlementService = mock(EntitlementService.class);
  private final AiDailyBudgetGuard aiDailyBudgetGuard = mock(AiDailyBudgetGuard.class);
  private final CreditReservationService creditReservationService = mock(CreditReservationService.class);
  private final RoutineCreationWriter routineCreationWriter = mock(RoutineCreationWriter.class);
  private final RoutineTranslationAi routineTranslationAi = mock(RoutineTranslationAi.class);
  private RoutineTranslateService service;

  @BeforeEach
  void setUp() {
    RoutineLibraryService routineLibraryService = new RoutineLibraryService(routineRepository, profileAccessGuard,
      mock(RoutineStepSpeechQueue.class), mock(RoutineGroupMembership.class), mock(ApplicationEventPublisher.class));
    service = new RoutineTranslateService(routineRepository, profileAccessGuard, entitlementService,
      aiDailyBudgetGuard, creditReservationService, routineCreationWriter, routineLibraryService,
      routineTranslationAi, mock(PlatformTransactionManager.class));
    when(creditReservationService.reserve(anyString(), eq(CreditJobKind.ROUTINE_TRANSLATE), anyString(), anyBoolean()))
      .thenReturn(CreditReservation.reserved("job-1"));
    when(creditReservationService.findSettledRoutineId(anyString(), anyString())).thenReturn(Optional.empty());
  }

  @Test
  @DisplayName("Free 는 AI·크레딧 예약 전에 ROUTINE_TRANSLATE_NOT_ALLOWED — 열어 두면 Free 가 Pro 기능을 쓰고 비용이 나간다")
  void free_isRejectedBeforeAiAndReservation() {
    givenRoutine(original(RoutineStatus.CONFIRMED));
    when(entitlementService.isAllowed("member-1", Entitlement.ROUTINE_TRANSLATE)).thenReturn(false);

    assertThatThrownBy(() -> service.translate(GUARDIAN, "routine-1", "en", "key-1"))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_TRANSLATE_NOT_ALLOWED);
    verify(routineTranslationAi, never()).translate(any(), any(), any(), any());
    verify(creditReservationService, never()).reserve(anyString(), any(), anyString(), anyBoolean());
  }

  @Test
  @DisplayName("Pro 번역은 일과관리 새 원본을 만든다: 번역 글·대상 언어, 그림 재사용, 원문 없음, 글 단가 정산 — 원본은 그대로")
  void pro_createsLibraryCopyWithTranslatedTexts() {
    Routine original = original(RoutineStatus.CONFIRMED);
    givenRoutine(original);
    when(entitlementService.isAllowed("member-1", Entitlement.ROUTINE_TRANSLATE)).thenReturn(true);
    when(routineTranslationAi.translate(any(), eq("하늘"), eq(AppLocale.KO), eq(AppLocale.EN)))
      .thenReturn(new RoutineTranslationDraft("Morning routine", "Sticker",
        List.of(new RoutineTranslationDraft.StepText("Brush teeth", "Brush your teeth"))));
    ArgumentCaptor<Routine> saved = ArgumentCaptor.forClass(Routine.class);
    when(routineRepository.save(saved.capture())).thenAnswer(invocation -> {
      Routine copy = invocation.getArgument(0);
      copy.setId("copy-1");
      return copy;
    });
    when(creditReservationService.settle("job-1", 1, 0, "copy-1", null)).thenReturn(new CreditSettlement(1, 0, 29));

    RoutineResponse response = service.translate(GUARDIAN, "routine-1", "en", "key-1");

    Routine copy = saved.getValue();
    assertThat(copy.getLanguage()).isEqualTo(AppLocale.EN);
    assertThat(copy.isLibraryOnly()).isTrue();
    assertThat(copy.getSourceRoutineId()).isNull();
    assertThat(copy.getTitle()).isEqualTo("Morning routine");
    assertThat(copy.getRawInputText()).isEqualTo("Morning routine");
    assertThat(copy.getRewardText()).isEqualTo("Sticker");
    assertThat(copy.getSteps()).extracting(RoutineStep::getDescription).containsExactly("Brush your teeth");
    assertThat(copy.getSteps()).extracting(RoutineStep::getImagePath).containsExactly("images/brush.png");
    assertThat(original.getTitle()).isEqualTo("아침 준비");
    assertThat(response.credit().charged()).isEqualTo(1);
  }

  @Test
  @DisplayName("AI 번역이 실패하면 사본을 저장하지 않고 예약을 돌려준다 — 남기면 반쪽 일과·잃은 크레딧이 생긴다")
  void aiFailure_savesNothingAndReleasesCredit() {
    givenRoutine(original(RoutineStatus.CONFIRMED));
    when(entitlementService.isAllowed("member-1", Entitlement.ROUTINE_TRANSLATE)).thenReturn(true);
    when(routineTranslationAi.translate(any(), any(), any(), any()))
      .thenThrow(new CustomException(ErrorCode.ROUTINE_TRANSLATE_FAILED));

    assertThatThrownBy(() -> service.translate(GUARDIAN, "routine-1", "en", "key-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_TRANSLATE_FAILED);
    verify(routineRepository, never()).save(any());
    verify(creditReservationService).release(eq("job-1"), anyString());
  }

  @Test
  @DisplayName("원래 언어·앱이 열지 않은 언어는 예약 전에 INVALID_INPUT_VALUE / 임시저장은 ROUTINE_INVALID_STATUS")
  void invalidLanguageOrDraft_isRejectedBeforeReservation() {
    when(entitlementService.isAllowed("member-1", Entitlement.ROUTINE_TRANSLATE)).thenReturn(true);
    givenRoutine(original(RoutineStatus.CONFIRMED));
    assertThatThrownBy(() -> service.translate(GUARDIAN, "routine-1", "ko", "key-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.INVALID_INPUT_VALUE);
    assertThatThrownBy(() -> service.translate(GUARDIAN, "routine-1", "ja", "key-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.INVALID_INPUT_VALUE);

    givenRoutine(original(RoutineStatus.PENDING_REVIEW));
    assertThatThrownBy(() -> service.translate(GUARDIAN, "routine-1", "en", "key-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_INVALID_STATUS);
    verify(creditReservationService, never()).reserve(anyString(), any(), anyString(), anyBoolean());
  }

  private void givenRoutine(Routine routine) {
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
  }

  /// 원본 (한국어, 카드 1장 · 그림 있음, 보상 있음, 만든 사람 member-1)
  private static Routine original(RoutineStatus status) {
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setNickname("하늘");
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setProfile(profile);
    routine.setCreatedBy("member-1");
    routine.setTitle("아침 준비");
    routine.setRawInputText("보호자 원문");
    routine.setSanitizedInputText("보호자 원문");
    routine.setRewardText("스티커");
    routine.setStatus(status);
    routine.setScheduledAt(LocalDateTime.now().minusDays(1));
    routine.setLanguage(AppLocale.KO);
    RoutineStep step = new RoutineStep();
    step.setId("step-1");
    step.setRoutine(routine);
    step.setStepOrder(1);
    step.setTitle("양치하기");
    step.setDescription("이를 닦아요");
    step.setImagePath("images/brush.png");
    step.setCompleted(true);
    routine.setSteps(new ArrayList<>(List.of(step)));
    return routine;
  }
}
