package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.FluxSeed;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.credit.application.service.CreditReservation;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.entity.ImageStyle;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.core.RoutineStepLimits;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineAiPipeline;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.core.RoutineStepSpeechText;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/// 보호자가 일과 카드를 한 장씩 추가·수정·삭제하는 쓰기. 일과 단위 쓰기는 RoutineService 가 맡는다.
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineStepEditService {

  /// 카드 추가 응답 imageSkippedReason — 이룸이의 그림 방식이 직접 사진이라 AI 그림을 만들지 않았다.
  static final String IMAGE_SKIPPED_PHOTO_ONLY = "IMAGE_STYLE_PHOTO_ONLY";

  private final RoutineRepository routineRepository;
  private final ProfileRepository profileRepository;
  private final RoutineStepImageFiller routineStepImageFiller;
  private final ProfileAccessGuard profileAccessGuard;
  private final RoutineStepRepository routineStepRepository;
  private final CreditReservationService creditReservationService;
  private final PictogramPicker pictogramPicker;
  private final RoutineStepSpeechQueue routineStepSpeechQueue;

  @Transactional
  public RoutineResponse updateStep(
    Caller caller, String routineId, String stepId, RoutineStepUpdateRequest request
  ) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    requireEditableRoutine(routine);

    List<RoutineStep> steps = routine.getSteps();
    RoutineStep targetStep = steps.stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));

    String speechTextBefore = RoutineStepSpeechText.of(targetStep.getTitle(), targetStep.getDescription());
    // 보낸 필드만 반영한다 — 넘어온 값을 그대로 덮어쓰면 순서만 보낼 때 제목·설명이 null로 지워진다.
    if (request.title() != null) {
      targetStep.setTitle(request.title());
    }
    if (request.description() != null) {
      targetStep.setDescription(request.description());
    }
    if (request.stepOrder() != null) {
      moveStep(steps, targetStep, request.stepOrder());
    }
    // 읽을 문장이 바뀌면 옛 음성 버리고 다시 만듦 (순서만 바꾸면 그대로)
    if (!speechTextBefore.equals(RoutineStepSpeechText.of(targetStep.getTitle(), targetStep.getDescription()))) {
      routineStepSpeechQueue.deleteSpeechAfterCommit(targetStep.getSpeechPath());
      targetStep.setSpeechPath(null);
      routineStepSpeechQueue.enqueueAfterCommit(targetStep.getId());
    }

    return RoutineResponse.from(routine);
  }

  /**
   * 카드를 원하는 자리로 옮기고 나머지를 1..N으로 다시 채운다.
   *
   * <p>화면은 화살표로 한 칸씩 민다. 클라가 낙관적으로 먼저 반영하고 실패하면 되돌리므로,
   * 서버는 <b>항상 연속된 값</b>으로 정규화해 응답한다 — 값이 겹치거나 비면 다음 이동에서
   * 순서가 튄다.
   *
   * <p>범위를 벗어난 값은 막지 않고 끝으로 붙인다. 화살표를 끝에서 한 번 더 눌렀을 때
   * 400을 던지면 화면이 되돌아가야 하는데, 사용자가 보기엔 아무 일도 아니다.
   */
  private void moveStep(List<RoutineStep> steps, RoutineStep target, int desiredOrder) {
    List<RoutineStep> ordered = new ArrayList<>(steps);
    ordered.sort(Comparator.comparingInt(RoutineStep::getStepOrder));
    ordered.remove(target);

    int index = Math.clamp(desiredOrder - 1, 0, ordered.size());
    ordered.add(index, target);

    for (int i = 0; i < ordered.size(); i++) {
      ordered.get(i).setStepOrder(i + 1);
    }
  }

  /**
   * 카드를 고칠 수 있는 상태인지 본다.
   *
   * <p>{@code PENDING_REVIEW}뿐 아니라 <b>이룸이에게 보낸 뒤에도</b> 고칠 수 있어야 한다. 전문가 자문의 필수 요구가
   * <i>"생성된 카드를 수정·순서 변경·삭제할 수 있어야 한다. 쉽게."</i> 이다.
   *
   * <p>지금은 모든 상태를 허용하므로 막는 경우가 없다. 그래도 메서드를 두는 이유는
   * 다시 조일 자리를 한 곳으로 모아 두기 위함이다 — 호출부 네 곳에 흩어지면
   * 한 군데만 고쳐져 어긋난다.
   */
  private void requireEditableRoutine(Routine routine) {
    // 현재는 PENDING_REVIEW · CONFIRMED · COMPLETED 모두 허용한다.
  }

  @Transactional
  public RoutineResponse deleteStep(Caller caller, String routineId, String stepId) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    requireEditableRoutine(routine);

    List<RoutineStep> steps = routine.getSteps();
    if (steps.size() <= 1) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_MIN_COUNT);
    }

    RoutineStep targetStep = steps.stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));

    // 이미 별을 받은 카드를 지우면 그 별도 함께 거둔다.
    // 별은 "완료한 카드 수"를 따라간다 — syncProgress(증감분)도 같은 규칙이다. 카드가 사라졌는데 별만 남으면
    // 이룸이 화면의 별 개수가 무엇을 센 것인지 설명할 수 없게 된다.
    // 보호자가 스스로 카드를 지울 때의 동작이다. 나가기에 의한 삭제는 별을 건드리지 않는다 (명세 4-3).
    if (Boolean.TRUE.equals(targetStep.getCompleted())) {
      profileRepository.addStars(routine.getProfile().getId(), -1);
    }

    steps.remove(targetStep);
    routineStepSpeechQueue.deleteStepsAfterCommit(List.of(targetStep.getId()));
    renumberSteps(steps);
    refreshCompletionStatus(routine);

    return RoutineResponse.from(routine);
  }

  /**
   * 보호자가 카드를 한 장 직접 추가한다.
   *
   * <p><b>그림을 기다리지 않는다.</b> 이미지 생성은 몇 초 걸리는데 응답을 그때까지
   * 붙잡으면 화면이 멈춘다. 카드를 먼저 만들어 응답하고, 그림은 커밋 뒤에 채운다.
   * 클라는 {@code imagePath}가 빌 동안 "그림 만드는 중"을 띄운다.
   *
   * <p><b>그림이 실패해도 카드 추가는 성공한다.</b> {@code imagePath}를 {@code null}로
   * 두고 끝낸다 — 클라가 기본 그림으로 채운다 (서비스 원칙 6).
   *
   * <p>하루 비용 상한이나 회원별 그림 횟수에 걸려도 같다 — 카드는 추가하고 그림만
   * 건너뛴다. 그래서 여기에는 일과 만들기의 쿨다운·한도를 걸지 않는다.
   *
   * <p><b>그림은 {@code generateImage=true} 일 때만 만든다.</b> 크레딧이 켜져 있으면 이 트랜잭션 안에서
   * 그림 1장을 예약한다(초과 허용 없음). 모자라거나 계정이 멈춰 있으면 카드는 저장하고 그림만 건너뛰며 응답에
   * 까닭을 싣는다. 예약 거절은 예약 트랜잭션이 정상으로 끝난 뒤 던져지므로 이 트랜잭션은 롤백 전용이 되지 않는다.
   * 장부 오류(AI_CREDIT_UNAVAILABLE)는 카드까지 실패시킨다 — 그 경우 예약 안에서 난 예외가 이 트랜잭션을
   * 이미 롤백 전용으로 만들어 카드만 저장할 수 없고, 장부 오류는 막는다(fail-closed).
   */
  @Transactional
  public RoutineResponse addStep(
    Caller caller, String routineId, RoutineStepCreateRequest request
  ) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    requireEditableRoutine(routine);

    List<RoutineStep> steps = routine.getSteps();
    // 카드 수 상한 (AI 생성과 같은 값). 지우면 자리가 다시 나므로 그림 횟수는 RoutineStepImageFiller 가 따로 묶음
    if (steps.size() >= RoutineStepLimits.MAX_STEP_COUNT) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_MAX_COUNT);
    }

    RoutineStep step = new RoutineStep();
    step.setRoutine(routine);
    step.setTitle(request.title().trim());
    step.setDescription(request.descriptionOrEmpty());
    // 그림이 없어도(직접 사진·AI 그림 실패·요금제) 카드에는 무료 픽토그램이 붙는다. 고르기는 절대 던지지 않는다.
    // 글 호출 단가 수준이라 크레딧을 잡지 않고, 그림 예약·건너뜀 판정(imageSkippedReason)과도 무관하다.
    // 보호자가 카드에 이룸이 이름을 적었을 수 있다 — 글 AI·그림 AI 로 나가는 값만 자리표시로 바꾸고 저장값은 그대로 둔다.
    String nickname = routine.getProfile().getNickname();
    // 요청 헤더(보호자 휴대폰 언어)가 아니라 이 일과의 언어를 따른다
    AppLocale language = routine.getLanguage() == null ? AppLocale.KO : routine.getLanguage();
    step.setPictogramId(AiCallContext.callWithContentLocale(language, () -> pictogramPicker.pick(
      caller.memberId(), NicknamePlaceholder.mask(step.getTitle(), nickname, language),
      NicknamePlaceholder.mask(step.getDescription(), nickname, language))));
    // 맨 뒤에 붙인다. 뒤이어 renumberSteps가 1..N으로 정규화하므로
    // 기존 값이 비어 있거나 겹쳐 있어도 결과는 연속값이 된다.
    step.setStepOrder(steps.size() + 1);
    step.setCompleted(false);
    steps.add(step);
    renumberSteps(steps);

    // 카드가 늘면 "전부 완료" 상태가 깨진다 — COMPLETED였다면 CONFIRMED로 되돌린다.
    refreshCompletionStatus(routine);

    // 지금 저장해 id 를 받는다. 목록에만 넣으면 커밋 때에야 id 가 매겨져, 그림 예약·정산에 넘길 카드 id 가
    // 비어 있어 그림 채우기가 "카드 없음"으로 끝난다.
    routineStepRepository.save(step);
    // 단계 음성은 그림 여부와 무관하게 커밋 뒤 만듦 (#675)
    routineStepSpeechQueue.enqueueAfterCommit(step.getId());

    // 직접 사진 방식: 그림 요청 여부와 무관하게 예약도 채우기 예약도 하지 않는다. 그림 몫 크레딧을
    // 잡지 않으니 청구도 없다. 그림을 원했는데 안 나온 까닭을 클라가 알 수 있게 사유를 싣는다.
    if (routine.getProfile().getImageStyle() == ImageStyle.PHOTO_ONLY) {
      RoutineResponse response = RoutineResponse.from(routine);
      return request.wantsImage() ? response.withImageSkippedReason(IMAGE_SKIPPED_PHOTO_ONLY) : response;
    }

    if (!request.wantsImage() || step.getDescription().isBlank()) {
      return RoutineResponse.from(routine);
    }

    String creditJobId;
    try {
      // 카드 추가는 멱등 키가 없다 — 요청마다 새 작업이다.
      CreditReservation reservation = creditReservationService.reserve(
        caller.memberId(), CreditJobKind.CARD_IMAGE, "card-image:" + UUID.randomUUID(), false);
      creditJobId = reservation.isReserved() ? reservation.jobId() : null;
    } catch (CustomException e) {
      if (e.getErrorCode() == ErrorCode.AI_CREDIT_INSUFFICIENT
        || e.getErrorCode() == ErrorCode.AI_CREDIT_ACCOUNT_FROZEN) {
        log.info("크레딧 거절 — 카드만 저장하고 그림은 건너뛴다: memberId={}, routineId={}, reason={}",
          caller.memberId(), routineId, e.getErrorCode());
        return RoutineResponse.from(routine).withImageSkippedReason(e.getErrorCode().name());
      }
      throw e;
    }

    // 커밋된 뒤에 그림을 만든다. 트랜잭션 안에서 돌리면 Gemini 호출(수 초) 동안
    // DB 커넥션을 붙잡고, 롤백되면 방금 쓴 이미지 파일이 고아로 남는다. 롤백되면 예약도 함께 사라진다.
    AiCallContext.runWithContentLocale(language, () -> routineStepImageFiller.scheduleAfterCommit(
      caller.memberId(), routineId, step.getId(), NicknamePlaceholder.mask(step.getDescription(), nickname, language),
      routine.getProfile().getCharacter(),
      FluxSeed.routineKey(routine.getProfile().getId(), routine.getTitle()), creditJobId,
      routine.getProfile().getImageStyle()));

    return RoutineResponse.from(routine);
  }

  /**
   * 카드가 늘거나 줄었을 때 일과의 완료 상태를 다시 계산한다.
   *
   * <p>{@code syncProgress}가 쓰는 규칙과 같다 — 전부 완료면 COMPLETED, 아니면 CONFIRMED.
   * 검토 중(PENDING_REVIEW)인 일과는 아직 이룸이에게 가지 않았으므로 건드리지 않는다.
   */
  private void refreshCompletionStatus(Routine routine) {
    if (routine.getStatus() == RoutineStatus.PENDING_REVIEW) {
      return;
    }
    List<RoutineStep> steps = routine.getSteps();
    boolean allCompleted =
      !steps.isEmpty() && steps.stream().allMatch(s -> Boolean.TRUE.equals(s.getCompleted()));
    if (allCompleted) {
      if (routine.getStatus() != RoutineStatus.COMPLETED) {
        routine.setStatus(RoutineStatus.COMPLETED);
        routine.setCompletedAt(LocalDateTime.now());
      }
    } else {
      routine.setStatus(RoutineStatus.CONFIRMED);
      routine.setCompletedAt(null);
    }
  }

  // 삭제 후 남은 단계들의 stepOrder를 1..N으로 다시 채운다. PENDING_REVIEW 단계는 완료 이력이
  // 전혀 없어 재채번이 완료/취소 순서 검증 로직과 충돌하지 않는다.
  private void renumberSteps(List<RoutineStep> steps) {
    List<RoutineStep> ordered = steps.stream()
      .sorted(Comparator.comparingInt(RoutineStep::getStepOrder))
      .toList();
    for (int i = 0; i < ordered.size(); i++) {
      ordered.get(i).setStepOrder(i + 1);
    }
  }

  private Routine getRoutineFor(Caller caller, String routineId, RoutineAction action) {
    return RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId, action);
  }
}
