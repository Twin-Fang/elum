package com.chuseok22.elumserver.expertroutine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.expertroutine.application.dto.response.ExpertRoutineSummaryResponse;
import com.chuseok22.elumserver.expertroutine.core.ExpertRoutineReviewStatus;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutine;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutineStep;
import com.chuseok22.elumserver.expertroutine.infrastructure.repository.ExpertRoutineRepository;
import com.chuseok22.elumserver.expertroutine.infrastructure.repository.ExpertRoutineStepRepository;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 앱 목록·미리 보기: 검수 전 일과가 보이거나, 다른 언어 일과가 섞이는 것을 막는다.
@ExtendWith(MockitoExtension.class)
class ExpertRoutineQueryServiceTest {

  @Mock
  private ExpertRoutineRepository expertRoutineRepository;
  @Mock
  private ExpertRoutineStepRepository expertRoutineStepRepository;
  @InjectMocks
  private ExpertRoutineQueryService queryService;

  @Test
  @DisplayName("목록은 검수 완료 + 요청 언어로 묻고, 첫 카드 그림을 붙여 돌려준다")
  void list_asksReviewedInRequestLanguage() {
    ExpertRoutine routine = visible();
    when(expertRoutineRepository.findByIsPublishedTrueAndReviewStatusAndLanguageOrderBySortOrderAscTitleAsc(
      ExpertRoutineReviewStatus.REVIEWED, AppLocale.JA)).thenReturn(List.of(routine));
    ExpertRoutineStep cover = new ExpertRoutineStep();
    cover.setExpertRoutineId("expert-1");
    cover.setPictogramId("school_bag");
    when(expertRoutineStepRepository.findByExpertRoutineIdInAndStepOrder(List.of("expert-1"), 0))
      .thenReturn(List.of(cover));

    List<ExpertRoutineSummaryResponse> list = queryService.list(null, null, AppLocale.JA);

    assertThat(list).singleElement().satisfies(summary -> {
      assertThat(summary.coverPictogramId()).isEqualTo("school_bag");
      assertThat(summary.category()).isEqualTo("DAILY_FLOW");
      assertThat(summary.stepCount()).isEqualTo(3);
    });
  }

  @Test
  @DisplayName("모르는 분류는 INVALID_INPUT_VALUE(400), 저장소를 부르지 않는다")
  void list_unknownCategory_isRejected() {
    assertThatThrownBy(() -> queryService.list("SCHOOL", "ko", AppLocale.KO))
      .isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode())
      .isEqualTo(ErrorCode.INVALID_INPUT_VALUE);
    verifyNoInteractions(expertRoutineRepository);
  }

  @Test
  @DisplayName("분류·언어 값을 주면 그 값으로 묻는다 (언어 값이 틀리면 요청 언어)")
  void list_categoryAndLanguageParameters() {
    when(expertRoutineRepository.findByIsPublishedTrueAndReviewStatusAndLanguageAndCategoryOrderBySortOrderAscTitleAsc(
      any(), any(), any())).thenReturn(List.of());

    queryService.list("COMMUNITY", "xx", AppLocale.EN);

    verify(expertRoutineRepository).findByIsPublishedTrueAndReviewStatusAndLanguageAndCategoryOrderBySortOrderAscTitleAsc(
      ExpertRoutineReviewStatus.REVIEWED, AppLocale.EN, TalkCategory.COMMUNITY);
    verifyNoInteractions(expertRoutineStepRepository);
  }

  @Test
  @DisplayName("공개만 켠 초안의 미리 보기는 EXPERT_ROUTINE_NOT_FOUND(404)")
  void detail_publishedDraft_isNotFound() {
    ExpertRoutine draft = visible();
    draft.setReviewStatus(ExpertRoutineReviewStatus.DRAFT);
    when(expertRoutineRepository.findById("expert-1")).thenReturn(Optional.of(draft));

    assertThatThrownBy(() -> queryService.detail("expert-1"))
      .isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode())
      .isEqualTo(ErrorCode.EXPERT_ROUTINE_NOT_FOUND);
    verify(expertRoutineStepRepository, org.mockito.Mockito.never())
      .findByExpertRoutineIdInAndStepOrder(any(), anyInt());
  }

  private static ExpertRoutine visible() {
    ExpertRoutine routine = new ExpertRoutine();
    routine.setId("expert-1");
    routine.setTitle("등교 준비");
    routine.setCategory(TalkCategory.DAILY_FLOW);
    routine.setLanguage(AppLocale.JA);
    routine.setPublished(true);
    routine.setReviewStatus(ExpertRoutineReviewStatus.REVIEWED);
    routine.setStepCount(3);
    return routine;
  }
}
