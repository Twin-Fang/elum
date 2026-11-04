package com.chuseok22.elumserver.expertroutine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.expertroutine.application.dto.request.ExpertRoutineInput;
import com.chuseok22.elumserver.expertroutine.application.dto.request.ExpertRoutineInput.StepInput;
import com.chuseok22.elumserver.expertroutine.core.ExpertRoutineReviewStatus;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutine;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutineStep;
import com.chuseok22.elumserver.expertroutine.infrastructure.repository.ExpertRoutineRepository;
import com.chuseok22.elumserver.expertroutine.infrastructure.repository.ExpertRoutineStepRepository;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot.StepSnapshot;
import com.chuseok22.elumserver.routine.application.service.RoutineShareService;
import java.util.List;
import java.util.Optional;
import java.util.stream.Stream;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 관리자 전문가 일과: 보호자 일과의 개인 정보가 공용 일과로 새거나, 검수 전 일과가 앱에 나가는 것을 막는다.
@ExtendWith(MockitoExtension.class)
class ExpertRoutineAdminServiceTest {

  @Mock
  private ExpertRoutineRepository expertRoutineRepository;
  @Mock
  private ExpertRoutineStepRepository expertRoutineStepRepository;
  @Mock
  private RoutineShareService routineShareService;

  private ExpertRoutineAdminService adminService;

  @BeforeEach
  void setUp() {
    PictogramCatalog catalog = new PictogramCatalog(List.of("school_bag", "wash_hands_,_to", "go_,_to"), "go_,_to");
    adminService = new ExpertRoutineAdminService(expertRoutineRepository, expertRoutineStepRepository,
      new ExpertRoutineInputRules(catalog), routineShareService);
    lenient().when(expertRoutineRepository.save(any(ExpertRoutine.class))).thenAnswer(invocation -> {
      ExpertRoutine routine = invocation.getArgument(0);
      routine.setId("expert-new");
      return routine;
    });
  }

  @Test
  @DisplayName("보호자 일과에서 만든 초안: 이룸이 호칭은 자리표시로, 사진·AI 그림은 빼고 번들 그림만, 숨긴 초안으로 저장한다")
  void createDraftFromRoutine_stripsPersonalData() {
    when(routineShareService.snapshotForCatalog("routine-1")).thenReturn(new RoutineShareSnapshot("routine-1",
      "하늘이 등교 준비", AppLocale.KO, "하늘", List.of(
      new StepSnapshot("s0", 0, "가방", "하늘이는 가방을 메요", "s0/abc.jpg", "school_bag", null, true),
      new StepSnapshot("s1", 1, "손", "하늘색 수건으로 손을 닦아요", "batch/1.png", null, "dry_hands", false))));

    ExpertRoutine draft = adminService.createDraftFromRoutine("routine-1", "kimchi");

    assertThat(draft.getTitle()).doesNotContain("하늘").contains("이룸이");
    assertThat(draft.isPublished()).isFalse();
    assertThat(draft.getReviewStatus()).isEqualTo(ExpertRoutineReviewStatus.DRAFT);
    assertThat(draft.getRewardText()).isNull();
    @SuppressWarnings("unchecked")
    ArgumentCaptor<List<ExpertRoutineStep>> steps = ArgumentCaptor.forClass(List.class);
    verify(expertRoutineStepRepository).saveAll(steps.capture());
    assertThat(steps.getValue()).extracting(ExpertRoutineStep::getText)
      .allSatisfy(text -> assertThat(text).doesNotContain("하늘").contains("이룸이"));
    assertThat(steps.getValue()).extracting(ExpertRoutineStep::getPictogramId).containsExactly("school_bag", null);
    assertThat(steps.getValue()).extracting(ExpertRoutineStep::getExampleImageId).containsExactly(null, "dry_hands");
    // 그림 파일 열쇠를 받을 칸 자체가 없어 사진·AI 그림은 옮겨지지 않음
    assertThat(Stream.of(ExpertRoutineStep.class.getDeclaredFields()).map(java.lang.reflect.Field::getName))
      .doesNotContain("imageKey", "imagePath");
  }

  @Test
  @DisplayName("초안(검수 전)은 공개할 수 없다 — EXPERT_ROUTINE_INVALID / NOT_REVIEWED")
  void setPublished_draft_isRejected() {
    ExpertRoutine draft = stored(ExpertRoutineReviewStatus.DRAFT, false);
    when(expertRoutineRepository.findById("expert-1")).thenReturn(Optional.of(draft));

    assertThatThrownBy(() -> adminService.setPublished("expert-1", true, "kimchi"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> {
        assertThat(((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.EXPERT_ROUTINE_INVALID);
        assertThat(((CustomException) e).getDetail()).isEqualTo(ExpertRoutineInputRules.REASON_NOT_REVIEWED);
      });
    assertThat(draft.isPublished()).isFalse();
  }

  @Test
  @DisplayName("공개 중인 일과를 초안으로 고쳐 저장하면 앱에서 내려간다")
  void update_backToDraft_unpublishes() {
    ExpertRoutine live = stored(ExpertRoutineReviewStatus.REVIEWED, true);
    when(expertRoutineRepository.findById("expert-1")).thenReturn(Optional.of(live));

    ExpertRoutine saved = adminService.update("expert-1", input("DRAFT", "school_bag"), "kimchi");

    assertThat(saved.isPublished()).isFalse();
    assertThat(saved.isVisibleInApp()).isFalse();
  }

  @Test
  @DisplayName("카탈로그에 없는 픽토그램 id 는 PICTOGRAM_UNKNOWN 으로 거절하고 저장하지 않는다 (앱에서 그림이 비는 카드 방지)")
  void create_unknownPictogram_isRejected() {
    assertThatThrownBy(() -> adminService.create(input("REVIEWED", "no_such_symbol"), "kimchi"))
      .isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getDetail())
      .isEqualTo(ExpertRoutineInputRules.REASON_PICTOGRAM_UNKNOWN);
    verify(expertRoutineRepository, never()).save(any());
  }

  private static ExpertRoutineInput input(String reviewStatus, String pictogramId) {
    return new ExpertRoutineInput("등교 준비", null, "DAILY_FLOW", "ko", null, null, "0", reviewStatus, null,
      List.of(new StepInput("가방을 메요", pictogramId, null), new StepInput("  ", null, null)));
  }

  private static ExpertRoutine stored(ExpertRoutineReviewStatus reviewStatus, boolean isPublished) {
    ExpertRoutine routine = new ExpertRoutine();
    routine.setId("expert-1");
    routine.setTitle("등교 준비");
    routine.setReviewStatus(reviewStatus);
    routine.setPublished(isPublished);
    routine.setStepCount(1);
    return routine;
  }
}
