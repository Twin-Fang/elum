package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.any;
import static org.mockito.Mockito.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepUpdateRequest;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineAiPipeline;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineRequestCooldownGuard;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
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
 * 카드 추가 · 순서 변경 (이슈 #199).
 *
 * <p><b>실제 AI를 부르지 않는다.</b> 이미지 생성은 {@link RoutineStepImageFiller}를 mock으로
 * 두고 "예약했는가"만 본다. 카드 한 장 = 이미지 1회 = 돈이다.
 */
@ExtendWith(MockitoExtension.class)
class RoutineStepEditTest {

  @Mock private RoutineRepository routineRepository;
  @Mock private RoutineImageStorage routineImageStorage;
  @Mock private ProfileRepository profileRepository;
  @Mock private RoutineAiPipeline routineAiPipeline;
  @Mock private RoutineRequestCooldownGuard routineRequestCooldownGuard;
  @Mock private RoutineStepImageFiller routineStepImageFiller;

  @InjectMocks private RoutineService routineService;

  // ── 카드 추가 ────────────────────────────────────────────────────

  @Test
  @DisplayName("추가한 카드는 맨 뒤에 붙고 순서는 1..N으로 이어진다")
  void addStep_appendsToEnd() {
    Routine routine = routine(RoutineStatus.PENDING_REVIEW, 3, false);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.addStep("member-1", "routine-1",
      new RoutineStepCreateRequest("우산을 챙겨요", "현관에서 우산을 챙겨요."));

    assertThat(routine.getSteps()).hasSize(4);
    assertThat(routine.getSteps()).extracting(RoutineStep::getStepOrder)
      .containsExactly(1, 2, 3, 4);
    RoutineStep added = routine.getSteps().get(3);
    assertThat(added.getTitle()).isEqualTo("우산을 챙겨요");
    assertThat(added.getCompleted()).isFalse();
    // 그림은 아직 없다 — 응답을 붙잡지 않으므로 나중에 채워진다
    assertThat(added.getImagePath()).isNull();
  }

  @Test
  @DisplayName("추가하면 그림 생성을 예약하되 응답을 기다리지 않는다")
  void addStep_schedulesImageWithoutBlocking() {
    Routine routine = routine(RoutineStatus.PENDING_REVIEW, 1, false);
    routine.getProfile().setCharacter(CharacterType.LULU);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.addStep("member-1", "routine-1",
      new RoutineStepCreateRequest("우산을 챙겨요", "현관에서 우산을 챙겨요."));

    // 그 일과의 캐릭터를 그대로 넘겨야 기존 카드들과 그림체가 맞는다.
    // 요청 회원도 넘겨야 그림 호출 기록에 회원이 남고 회원별 그림 횟수를 셀 수 있다 (#368).
    verify(routineStepImageFiller).scheduleAfterCommit(
      eq("member-1"), eq("routine-1"), any(), eq("현관에서 우산을 챙겨요."), eq(CharacterType.LULU));
  }

  @Test
  @DisplayName("카드가 10장이면 더 추가할 수 없다 — AI 생성 상한과 같은 값")
  void addStep_atMaxCount_throws() {
    Routine routine = routine(RoutineStatus.PENDING_REVIEW, 10, false);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> routineService.addStep("member-1", "routine-1",
      new RoutineStepCreateRequest("열한 번째", "안 된다")))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_STEP_MAX_COUNT);

    // 거부했으면 돈 쓰는 일도 시작하지 않아야 한다
    verifyNoInteractions(routineStepImageFiller);
  }

  @Test
  @DisplayName("이룸이에게 보낸 뒤(CONFIRMED)에도 카드를 추가할 수 있다 — 전문가 자문 요구")
  void addStep_confirmedRoutine_allowed() {
    Routine routine = routine(RoutineStatus.CONFIRMED, 2, false);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.addStep("member-1", "routine-1",
      new RoutineStepCreateRequest("하나 더", "설명"));

    assertThat(routine.getSteps()).hasSize(3);
  }

  @Test
  @DisplayName("다 끝낸 일과에 카드를 더하면 완료가 풀려 CONFIRMED로 돌아간다")
  void addStep_completedRoutine_returnsToConfirmed() {
    Routine routine = routine(RoutineStatus.COMPLETED, 2, true);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.addStep("member-1", "routine-1",
      new RoutineStepCreateRequest("하나 더", "설명"));

    assertThat(routine.getStatus()).isEqualTo(RoutineStatus.CONFIRMED);
    assertThat(routine.getCompletedAt()).isNull();
  }

  @Test
  @DisplayName("설명이 비면 그림을 부르지 않는다 — 빈 프롬프트는 돈만 쓴다")
  void addStep_blankDescription_skipsImage() {
    Routine routine = routine(RoutineStatus.PENDING_REVIEW, 1, false);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.addStep("member-1", "routine-1",
      new RoutineStepCreateRequest("제목만", null));

    assertThat(routine.getSteps().get(1).getDescription()).isEmpty();
    // 예약 자체는 부르되, 빈 설명이면 Filler가 내부에서 걸러 낸다
    verify(routineStepImageFiller).scheduleAfterCommit(any(), any(), any(), eq(""), any());
  }

  // ── 순서 변경 ────────────────────────────────────────────────────

  @Test
  @DisplayName("stepOrder만 보내면 제목·설명은 그대로 남는다")
  void updateStep_orderOnly_keepsTitleAndDescription() {
    Routine routine = routine(RoutineStatus.PENDING_REVIEW, 3, false);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.updateStep("member-1", "routine-1", "step-3",
      new RoutineStepUpdateRequest(null, null, 1));

    RoutineStep moved = routine.getSteps().stream()
      .filter(s -> s.getId().equals("step-3")).findFirst().orElseThrow();
    assertThat(moved.getTitle()).isEqualTo("제목 3");
    assertThat(moved.getDescription()).isEqualTo("단계 3");
    assertThat(moved.getStepOrder()).isEqualTo(1);
  }

  @Test
  @DisplayName("한 칸 옮기면 나머지가 1..N으로 다시 채워진다")
  void updateStep_move_renumbersContiguously() {
    Routine routine = routine(RoutineStatus.PENDING_REVIEW, 4, false);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    // 4번째를 2번 자리로
    routineService.updateStep("member-1", "routine-1", "step-4",
      new RoutineStepUpdateRequest(null, null, 2));

    assertThat(sortedIds(routine)).containsExactly("step-1", "step-4", "step-2", "step-3");
    assertThat(routine.getSteps()).extracting(RoutineStep::getStepOrder)
      .containsExactlyInAnyOrder(1, 2, 3, 4);
  }

  @Test
  @DisplayName("범위를 넘는 자리를 보내면 끝으로 붙인다 — 화살표를 끝에서 더 눌러도 깨지지 않는다")
  void updateStep_orderOutOfRange_clampsToEnd() {
    Routine routine = routine(RoutineStatus.PENDING_REVIEW, 3, false);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.updateStep("member-1", "routine-1", "step-1",
      new RoutineStepUpdateRequest(null, null, 99));

    assertThat(sortedIds(routine)).containsExactly("step-2", "step-3", "step-1");
  }

  @Test
  @DisplayName("보낸 뒤(CONFIRMED)에도 순서를 바꿀 수 있다")
  void updateStep_confirmedRoutine_allowed() {
    Routine routine = routine(RoutineStatus.CONFIRMED, 3, false);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.updateStep("member-1", "routine-1", "step-3",
      new RoutineStepUpdateRequest(null, null, 1));

    assertThat(sortedIds(routine)).containsExactly("step-3", "step-1", "step-2");
  }

  // ── 삭제 ────────────────────────────────────────────────────────

  @Test
  @DisplayName("이미 별을 받은 카드를 지우면 그 별도 함께 거둔다")
  void deleteStep_completedStep_reclaimsStar() {
    Routine routine = routine(RoutineStatus.CONFIRMED, 3, false);
    routine.getSteps().get(0).setCompleted(true);
    routine.getProfile().setTotalStars(1);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.deleteStep("member-1", "routine-1", "step-1");

    assertThat(routine.getProfile().getTotalStars()).isZero();
    assertThat(routine.getSteps()).hasSize(2);
  }

  @Test
  @DisplayName("아직 안 한 카드를 지우면 별은 그대로다")
  void deleteStep_incompleteStep_keepsStars() {
    Routine routine = routine(RoutineStatus.CONFIRMED, 3, false);
    routine.getSteps().get(0).setCompleted(true);
    routine.getProfile().setTotalStars(1);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.deleteStep("member-1", "routine-1", "step-3");

    assertThat(routine.getProfile().getTotalStars()).isEqualTo(1);
  }

  @Test
  @DisplayName("남은 미완료 카드를 지워 전부 완료가 되면 일과가 COMPLETED가 된다")
  void deleteStep_lastIncomplete_completesRoutine() {
    Routine routine = routine(RoutineStatus.CONFIRMED, 2, false);
    routine.getSteps().get(0).setCompleted(true);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    routineService.deleteStep("member-1", "routine-1", "step-2");

    assertThat(routine.getStatus()).isEqualTo(RoutineStatus.COMPLETED);
    assertThat(routine.getCompletedAt()).isNotNull();
  }

  @Test
  @DisplayName("마지막 한 장은 여전히 지울 수 없다")
  void deleteStep_lastRemaining_throws() {
    Routine routine = routine(RoutineStatus.CONFIRMED, 1, false);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> routineService.deleteStep("member-1", "routine-1", "step-1"))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_STEP_MIN_COUNT);
  }

  @Test
  @DisplayName("남의 일과는 건드릴 수 없다")
  void addStep_notOwner_throws() {
    Routine routine = routine(RoutineStatus.PENDING_REVIEW, 1, false);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> routineService.addStep("other-member", "routine-1",
      new RoutineStepCreateRequest("제목", "설명")))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_ACCESS_DENIED);

    verify(routineStepImageFiller, never()).scheduleAfterCommit(any(), any(), any(), any(), any());
  }

  // ── 헬퍼 ────────────────────────────────────────────────────────

  private List<String> sortedIds(Routine routine) {
    return routine.getSteps().stream()
      .sorted(java.util.Comparator.comparingInt(RoutineStep::getStepOrder))
      .map(RoutineStep::getId)
      .toList();
  }

  private Routine routine(RoutineStatus status, int stepCount, boolean allCompleted) {
    Member member = new Member();
    member.setId("member-1");
    Profile profile = new Profile();
    profile.setId("profile-1");
    profile.setMember(member);
    profile.setTotalStars(0);

    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setProfile(profile);
    routine.setStatus(status);

    List<RoutineStep> steps = new ArrayList<>();
    for (int i = 1; i <= stepCount; i++) {
      RoutineStep step = new RoutineStep();
      step.setId("step-" + i);
      step.setStepOrder(i);
      step.setTitle("제목 " + i);
      step.setDescription("단계 " + i);
      step.setCompleted(allCompleted);
      steps.add(step);
    }
    routine.setSteps(steps);
    return routine;
  }
}
