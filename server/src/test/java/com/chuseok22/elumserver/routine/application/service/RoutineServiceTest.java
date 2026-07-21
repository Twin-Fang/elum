package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.eq;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.SensitiveInfoGuardService;
import com.chuseok22.elumserver.ai.core.SensitiveInfoCheckResult;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineQuestionResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineAiPipeline;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class RoutineServiceTest {

  @Mock
  private RoutineRepository routineRepository;

  @Mock
  private RoutineImageStorage routineImageStorage;

  @Mock
  private MemberRepository memberRepository;

  @Mock
  private SensitiveInfoGuardService sensitiveInfoGuardService;

  @Mock
  private RoutineAiPipeline routineAiPipeline;

  @InjectMocks
  private RoutineService routineService;

  @Test
  @DisplayName("본인 소유 일과의 단계 이미지를 조회하면 저장된 이미지 내용을 반환한다")
  void getStepImage_ownedRoutine_returnsImageContent() {
    Member member = new Member();
    member.setId("member-1");
    Routine routine = new Routine();
    routine.setMember(member);
    RoutineStep step = new RoutineStep();
    step.setId("step-1");
    step.setImagePath("data/routine-images/batch-1/1.png");
    routine.setSteps(List.of(step));
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    RoutineImageStorage.ImageContent expected =
      new RoutineImageStorage.ImageContent(new byte[]{1, 2, 3}, "image/png");
    when(routineImageStorage.read("data/routine-images/batch-1/1.png")).thenReturn(expected);

    RoutineImageStorage.ImageContent result = routineService.getStepImage("member-1", "routine-1", "step-1");

    assertThat(result).isEqualTo(expected);
  }

  @Test
  @DisplayName("다른 회원의 일과에 접근하면 ROUTINE_ACCESS_DENIED를 던진다")
  void getStepImage_notOwner_throwsAccessDenied() {
    Member member = new Member();
    member.setId("member-1");
    Routine routine = new Routine();
    routine.setMember(member);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> routineService.getStepImage("member-2", "routine-1", "step-1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_ACCESS_DENIED));
  }

  @Test
  @DisplayName("존재하지 않는 단계를 조회하면 ROUTINE_STEP_NOT_FOUND를 던진다")
  void getStepImage_missingStep_throwsStepNotFound() {
    Member member = new Member();
    member.setId("member-1");
    Routine routine = new Routine();
    routine.setMember(member);
    routine.setSteps(List.of());
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertThatThrownBy(() -> routineService.getStepImage("member-1", "routine-1", "missing-step"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.ROUTINE_STEP_NOT_FOUND));
  }

  @Test
  @DisplayName("선택한 도움 목표가 없으면 질문 없이 required:false를 반환한다")
  void generateQuestion_noRelevantGoals_returnsNotRequired() {
    Member member = new Member();
    member.setId("member-1");
    member.setSupportGoals(Set.of(SupportGoal.STEP_BY_STEP));
    when(memberRepository.findById("member-1")).thenReturn(Optional.of(member));

    RoutineQuestionResponse response =
      routineService.generateQuestion("member-1", new RoutineQuestionRequest("내일 병원 가기"));

    assertThat(response.required()).isFalse();
    assertThat(response.questions()).isEmpty();
  }

  @Test
  @DisplayName("PREPARE_ITEMS를 선택했으면 AI 파이프라인 결과를 질문 목록으로 반환한다")
  void generateQuestion_relevantGoal_returnsQuestions() {
    Member member = new Member();
    member.setId("member-1");
    member.setNickname("하늘이");
    member.setSupportGoals(Set.of(SupportGoal.PREPARE_ITEMS));
    when(memberRepository.findById("member-1")).thenReturn(Optional.of(member));
    when(sensitiveInfoGuardService.check("내일 비 오는 날 학교 가기"))
      .thenReturn(new SensitiveInfoCheckResult(true, false, List.of(), "정상", "내일 비 오는 날 학교 가기"));
    RoutineAiPipeline.RoutineQuestionResult pipelineResult = new RoutineAiPipeline.RoutineQuestionResult(
      List.of(new RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem(
        "챙겨야 하는 준비물이 있나요?", List.of("우산", "우비")
      ))
    );
    when(routineAiPipeline.generateQuestion(
      eq("하늘이"), eq(Set.of(SupportGoal.PREPARE_ITEMS)), eq("내일 비 오는 날 학교 가기")
    )).thenReturn(pipelineResult);

    RoutineQuestionResponse response =
      routineService.generateQuestion("member-1", new RoutineQuestionRequest("내일 비 오는 날 학교 가기"));

    assertThat(response.required()).isTrue();
    assertThat(response.questions()).hasSize(1);
    assertThat(response.questions().get(0).question()).isEqualTo("챙겨야 하는 준비물이 있나요?");
  }
}
