package com.chuseok22.elumserver.expertroutine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.expertroutine.application.dto.request.ExpertRoutineImportRequest;
import com.chuseok22.elumserver.expertroutine.application.dto.response.ExpertRoutineImportResponse;
import com.chuseok22.elumserver.expertroutine.core.ExpertRoutineReviewStatus;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutine;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutineStep;
import com.chuseok22.elumserver.expertroutine.infrastructure.repository.ExpertRoutineRepository;
import com.chuseok22.elumserver.expertroutine.infrastructure.repository.ExpertRoutineStepRepository;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.RoutineImportDraft;
import com.chuseok22.elumserver.routine.application.service.RoutineShareService;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 가져오기: Free 가 Pro 기능을 쓰거나, 내린·검수 전 일과가 보호자 일과관리로 들어가는 것을 막는다.
@ExtendWith(MockitoExtension.class)
class ExpertRoutineImportServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");

  @Mock
  private ExpertRoutineRepository expertRoutineRepository;
  @Mock
  private ExpertRoutineStepRepository expertRoutineStepRepository;
  @Mock
  private EntitlementService entitlementService;
  @Mock
  private RoutineShareService routineShareService;

  private ExpertRoutineImportService importService;

  @BeforeEach
  void setUp() {
    importService = new ExpertRoutineImportService(
      new ExpertRoutineQueryService(expertRoutineRepository, expertRoutineStepRepository),
      expertRoutineRepository, entitlementService, routineShareService);
  }

  @Test
  @DisplayName("Free 는 EXPERT_ROUTINE_PRO_ONLY(403), 일과를 만들지 않고 횟수도 그대로다")
  void importToLibrary_free_isRejected() {
    doThrow(new CustomException(Entitlement.ROUTINE_TEMPLATES.rejectionCode())).when(entitlementService).requireAllowed("member-1", Entitlement.ROUTINE_TEMPLATES);

    assertThatThrownBy(() -> importService.importToLibrary(GUARDIAN, "expert-1", new ExpertRoutineImportRequest("profile-1", null)))
      .isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode())
      .isEqualTo(ErrorCode.EXPERT_ROUTINE_PRO_ONLY);
    assertThat(ErrorCode.EXPERT_ROUTINE_PRO_ONLY.getStatus().value()).isEqualTo(403);
    verifyNoInteractions(routineShareService);
    verify(expertRoutineRepository, never()).increaseImportCount(any());
  }

  @Test
  @DisplayName("내렸거나 검수 전(공개만 켠 초안)인 일과는 EXPERT_ROUTINE_NOT_FOUND, 일과를 만들지 않는다")
  void importToLibrary_hiddenOrDraft_isNotFound() {
    when(expertRoutineRepository.findById("hidden")).thenReturn(Optional.of(expert(false, ExpertRoutineReviewStatus.REVIEWED)));
    when(expertRoutineRepository.findById("draft")).thenReturn(Optional.of(expert(true, ExpertRoutineReviewStatus.DRAFT)));
    when(expertRoutineRepository.findById("gone")).thenReturn(Optional.empty());

    for (String id : List.of("hidden", "draft", "gone")) {
      assertThatThrownBy(() -> importService.importToLibrary(GUARDIAN, id, new ExpertRoutineImportRequest("profile-1", null)))
        .as(id)
        .isInstanceOf(CustomException.class)
        .extracting(e -> ((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.EXPERT_ROUTINE_NOT_FOUND);
    }
    verifyNoInteractions(routineShareService);
  }

  @Test
  @DisplayName("Pro 는 카드 문장·픽토그램·보상을 그대로 원본 일과로 복사한다 (이야기 글 아님, 그림 파일 없음 = AI·크레딧 없음)")
  void importToLibrary_pro_copiesAsOriginalWithoutAi() {
    when(expertRoutineRepository.findById("expert-1")).thenReturn(Optional.of(expert(true, ExpertRoutineReviewStatus.REVIEWED)));
    when(expertRoutineStepRepository.findByExpertRoutineIdOrderByStepOrderAsc("expert-1"))
      .thenReturn(List.of(step(0, "손을 씻어요", "wash_hands_,_to"), step(1, "손을 닦아요", null)));
    when(routineShareService.importToLibrary(eq(GUARDIAN), eq("profile-1"), eq(null), any())).thenReturn("routine-1");

    ExpertRoutineImportResponse response = importService.importToLibrary(
      GUARDIAN, "expert-1", new ExpertRoutineImportRequest("profile-1", null));

    assertThat(response.routineId()).isEqualTo("routine-1");
    assertThat(response.profileId()).isEqualTo("profile-1");
    ArgumentCaptor<RoutineImportDraft> draft = ArgumentCaptor.forClass(RoutineImportDraft.class);
    verify(routineShareService).importToLibrary(eq(GUARDIAN), eq("profile-1"), eq(null), draft.capture());
    assertThat(draft.getValue().talkPostId()).isNull();
    assertThat(draft.getValue().title()).isEqualTo("손 씻기");
    assertThat(draft.getValue().language()).isEqualTo(AppLocale.EN);
    assertThat(draft.getValue().rewardText()).isEqualTo("칭찬 스티커");
    assertThat(draft.getValue().rewardPresetKey()).isEqualTo("SNACK");
    assertThat(draft.getValue().steps()).extracting(RoutineImportDraft.DraftStep::description)
      .containsExactly("손을 씻어요", "손을 닦아요");
    assertThat(draft.getValue().steps()).extracting(RoutineImportDraft.DraftStep::pictogramId)
      .containsExactly("wash_hands_,_to", null);
    assertThat(draft.getValue().steps()).allMatch(step -> step.image() == null);
    verify(expertRoutineRepository).increaseImportCount("expert-1");
  }

  @Test
  @DisplayName("이룸이 id 가 비면 INVALID_INPUT_VALUE, 권한도 묻지 않는다")
  void importToLibrary_blankProfile_isInvalid() {
    assertThatThrownBy(() -> importService.importToLibrary(GUARDIAN, "expert-1", new ExpertRoutineImportRequest(" ", null)))
      .isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode())
      .isEqualTo(ErrorCode.INVALID_INPUT_VALUE);
    verifyNoInteractions(entitlementService, routineShareService);
  }

  private static ExpertRoutine expert(boolean isPublished, ExpertRoutineReviewStatus reviewStatus) {
    ExpertRoutine routine = new ExpertRoutine();
    routine.setId("expert-1");
    routine.setTitle("손 씻기");
    routine.setCategory(TalkCategory.SELF_CARE);
    routine.setLanguage(AppLocale.EN);
    routine.setRewardText("칭찬 스티커");
    routine.setRewardPresetKey("SNACK");
    routine.setPublished(isPublished);
    routine.setReviewStatus(reviewStatus);
    routine.setStepCount(2);
    return routine;
  }

  private static ExpertRoutineStep step(int order, String text, String pictogramId) {
    ExpertRoutineStep step = new ExpertRoutineStep();
    step.setExpertRoutineId("expert-1");
    step.setStepOrder(order);
    step.setText(text);
    step.setPictogramId(pictogramId);
    return step;
  }
}
