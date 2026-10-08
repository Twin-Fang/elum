package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.FluxSeed;
import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.service.CreditReservation;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.entity.ImageStyle;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.application.dto.request.RewardUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineAiPipeline;
import com.chuseok22.elumserver.routine.infrastructure.constant.RewardPreset;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/// 보호자가 일과를 승인·편집·정렬·삭제하는 쓰기. 생성·조회·진행은 각 서비스가 맡는다.
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineService {

  /// 한 일과에 담을 수 있는 카드 수 상한 (이슈 #199).
  ///
  /// AI 생성 경로가 이미 같은 값으로 막혀 있다(`RoutineAiPipeline.MAX_STEPS`, 프롬프트도
  /// "1개 이상 10개 이하"). 같은 값으로 맞춰야 **기존 일과 중 상한을 넘는 것이 없다** —
  /// 더 낮게 잡으면 AI가 만든 일과가 처음부터 상한 초과 상태가 된다.
  ///
  /// 카드 1장을 추가할 때마다 AI 이미지가 1회 생성된다. 다만 이 상한은 비용의 천장이
  /// 아니다 — 지우면 자리가 다시 나서 추가·삭제를 되풀이할 수 있다. 그림 횟수는
  /// {@link RoutineStepImageFiller}가 따로 묶는다 (#368).
  private static final int STEP_MAX_COUNT = 10;

  /// 카드 추가 응답 imageSkippedReason — 이룸이의 그림 방식이 직접 사진이라 AI 그림을 만들지 않았다(#457).
  static final String IMAGE_SKIPPED_PHOTO_ONLY = "IMAGE_STYLE_PHOTO_ONLY";

  private final RoutineRepository routineRepository;
  private final ProfileRepository profileRepository;
  private final RoutineStepImageFiller routineStepImageFiller;
  private final ProfileAccessGuard profileAccessGuard;
  private final RoutineStepRepository routineStepRepository;
  private final CreditReservationService creditReservationService;
  private final PictogramPicker pictogramPicker;

  @Transactional
  public RoutineResponse confirm(Caller caller, String routineId) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    if (routine.getStatus() != RoutineStatus.PENDING_REVIEW) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }
    routine.setStatus(RoutineStatus.CONFIRMED);
    // 승인한 날이 곧 그 일과를 하는 날이다.
    // 날짜 선택 UI를 두지 않는 대신, 미리 만들어 둔 일과를 그날 승인하면 그날 일과가 된다.
    // (아이 홈은 scheduledAt이 오늘인 CONFIRMED만 조회하므로 이 갱신이 없으면 미리 만든 일과가 뜨지 않는다)
    routine.setScheduledAt(LocalDate.now().atTime(9, 0));
    return RoutineResponse.from(routine);
  }

  /// 보상만 수정한다. 일과를 만든 뒤에도 보호자가 바꿀 수 있어야
  /// "보호자가 관리한다"가 성립한다 (2026-09-13 자문).
  @Transactional
  public RoutineResponse updateReward(Caller caller, String routineId, RewardUpdateRequest request) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    routine.setRewardText(RoutineRules.trimReward(request.rewardText()));
    routine.setRewardPresetKey(RewardPreset.normalize(request.rewardPresetKey()));
    return RoutineResponse.from(routine);
  }

  /// 지난 일과를 오늘 일과로 복제한다. **AI를 호출하지 않는다** —
  /// 매일 같은 준비를 하는 경우 탭 한 번으로 끝나야 재사용 가치가 있다.
  ///
  /// 원문(`rawInputText`·`sanitizedInputText`)은 복사하지 않는다. 원문을 계속 들고 다니지 않는다는
  /// 서비스 원칙에 맞추고, 복제본은 카드만 있으면 수행에 지장이 없다.
  @Transactional
  public RoutineResponse duplicate(Caller caller, String routineId) {
    Routine origin = getRoutineFor(caller, routineId, RoutineAction.COPY);

    Routine copy = new Routine();
    copy.setProfile(origin.getProfile());
    // 복제본은 복제한 사람의 일과다. 원본을 누가 만들었든 원본은 그대로 남는다.
    copy.setCreatedBy(caller.memberId());
    copy.setRawInputText(origin.getTitle());
    copy.setSanitizedInputText(origin.getTitle());
    copy.setTitle(origin.getTitle());
    // 카드 글이 원본 그대로이므로 언어도 원본을 따른다 (복제한 사람의 화면 언어가 아니다)
    copy.setLanguage(origin.getLanguage());
    copy.setScheduledAt(LocalDate.now().atTime(9, 0));
    // 이미 검토를 거친 카드라 다시 승인받지 않는다. 바로 오늘 할 일이 된다.
    copy.setStatus(RoutineStatus.CONFIRMED);
    copy.setRewardText(origin.getRewardText());
    copy.setRewardPresetKey(origin.getRewardPresetKey());

    List<RoutineStep> copiedSteps = new ArrayList<>();
    for (RoutineStep step : origin.getSteps()) {
      RoutineStep copied = new RoutineStep();
      copied.setRoutine(copy);
      copied.setStepOrder(step.getStepOrder());
      copied.setTitle(step.getTitle());
      copied.setDescription(step.getDescription());
      // 이미지는 새로 만들지 않고 그대로 쓴다 — 재생성은 비용이고 같은 행동이면 같은 그림이면 된다.
      copied.setImagePath(step.getImagePath());
      // 픽토그램도 그대로 — 같은 행동이면 같은 그림이고, 복제에서 AI 를 다시 부르지 않는다.
      copied.setPictogramId(step.getPictogramId());
      copied.setCompleted(false);
      copiedSteps.add(copied);
    }
    copy.setSteps(copiedSteps);

    return RoutineResponse.from(routineRepository.save(copy));
  }

  /// 이룸이가 **아직 시작하지 않은** 일과만 삭제한다 (#533).
  ///
  /// 임시저장(`PENDING_REVIEW`)과, 보냈지만 한 단계도 하지 않은 `CONFIRMED` 가 대상이다.
  /// 예전에는 임시저장만 지울 수 있었는데, 보호자 홈 `오늘 일과`에 삭제 버튼이 있어
  /// 누를 때마다 409 만 받았다. 잘못 보낸 일과를 거둘 길이 없었다.
  ///
  /// 한 단계라도 한 일과는 지우지 않는다 — 수행률 추이의 원본 데이터이고,
  /// 보호자가 "이 날은 왜 못 했지"를 확인하는 근거다. 받은 별도 그 기록에 묶여 있다.
  @Transactional
  public void delete(Caller caller, String routineId) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    if (!isDeletable(routine)) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }
    routineRepository.delete(routine);
  }

  private boolean isDeletable(Routine routine) {
    return switch (routine.getStatus()) {
      case PENDING_REVIEW -> true;
      case CONFIRMED -> RoutineRules.countCompleted(routine.getSteps()) == 0;
      default -> false;
    };
  }

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

    // 보낸 필드만 반영한다. 예전에는 넘어온 값을 그대로 덮어써서, 순서만 보내면
    // 제목·설명이 null로 지워졌다.
    if (request.title() != null) {
      targetStep.setTitle(request.title());
    }
    if (request.description() != null) {
      targetStep.setDescription(request.description());
    }
    if (request.stepOrder() != null) {
      moveStep(steps, targetStep, request.stepOrder());
    }

    return RoutineResponse.from(routine);
  }

  /**
   * 카드를 원하는 자리로 옮기고 나머지를 1..N으로 다시 채운다 (이슈 #199).
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
   * 카드를 고칠 수 있는 상태인지 본다 (이슈 #199).
   *
   * <p>예전에는 {@code PENDING_REVIEW}만 허용했다. 전문가 자문의 필수 요구가
   * <i>"생성된 카드를 수정·순서 변경·삭제할 수 있어야 한다. 쉽게."</i> 라서,
   * <b>이룸이에게 보낸 뒤에도</b> 고칠 수 있어야 한다.
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

    // 이미 별을 받은 카드를 지우면 그 별도 함께 거둔다 (이슈 #199).
    // 별은 "완료한 카드 수"를 따라간다 — completeStep(+1) · cancelStep(-1) ·
    // syncProgress(증감분)가 모두 그 규칙이다. 카드가 사라졌는데 별만 남으면
    // 이룸이 화면의 별 개수가 무엇을 센 것인지 설명할 수 없게 된다.
    // 보호자가 스스로 카드를 지울 때의 동작이다. 나가기에 의한 삭제는 별을 건드리지 않는다 (명세 4-3).
    if (Boolean.TRUE.equals(targetStep.getCompleted())) {
      profileRepository.addStars(routine.getProfile().getId(), -1);
    }

    steps.remove(targetStep);
    renumberSteps(steps);
    refreshCompletionStatus(routine);

    return RoutineResponse.from(routine);
  }

  /**
   * 보호자가 카드를 한 장 직접 추가한다 (이슈 #199).
   *
   * <p><b>그림을 기다리지 않는다.</b> 이미지 생성은 몇 초 걸리는데 응답을 그때까지
   * 붙잡으면 화면이 멈춘다. 카드를 먼저 만들어 응답하고, 그림은 커밋 뒤에 채운다.
   * 클라는 {@code imagePath}가 빌 동안 "그림 만드는 중"을 띄운다 (#198 §9).
   *
   * <p><b>그림이 실패해도 카드 추가는 성공한다.</b> {@code imagePath}를 {@code null}로
   * 두고 끝낸다 — 클라가 기본 그림으로 채운다 (서비스 원칙 6).
   *
   * <p>하루 비용 상한이나 회원별 그림 횟수에 걸려도 같다 — 카드는 추가하고 그림만
   * 건너뛴다 (#368). 그래서 여기에는 일과 만들기의 쿨다운·한도를 걸지 않는다.
   *
   * <p><b>그림은 {@code generateImage=true} 일 때만 만든다 (#407).</b> 크레딧이 켜져 있으면 이 트랜잭션 안에서
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
    if (steps.size() >= STEP_MAX_COUNT) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_MAX_COUNT);
    }

    RoutineStep step = new RoutineStep();
    step.setRoutine(routine);
    step.setTitle(request.title().trim());
    step.setDescription(request.descriptionOrEmpty());
    // 그림이 없어도(직접 사진·AI 그림 실패·요금제) 카드에는 무료 픽토그램이 붙는다(#247). 고르기는 절대 던지지 않는다.
    // 글 호출 단가 수준이라 크레딧을 잡지 않고, 그림 예약·건너뜀 판정(imageSkippedReason)과도 무관하다.
    // 보호자가 카드에 이룸이 이름을 적었을 수 있다 — 글 AI·그림 AI 로 나가는 값만 자리표시로 바꾸고 저장값은 그대로 둔다 (#374).
    String nickname = routine.getProfile().getNickname();
    step.setPictogramId(pictogramPicker.pick(
      caller.memberId(), NicknamePlaceholder.mask(step.getTitle(), nickname),
      NicknamePlaceholder.mask(step.getDescription(), nickname)));
    // 맨 뒤에 붙인다. 뒤이어 renumberSteps가 1..N으로 정규화하므로
    // 기존 값이 비어 있거나 겹쳐 있어도 결과는 연속값이 된다.
    step.setStepOrder(steps.size() + 1);
    step.setCompleted(false);
    steps.add(step);
    renumberSteps(steps);

    // 카드가 늘면 "전부 완료" 상태가 깨진다 — COMPLETED였다면 CONFIRMED로 되돌린다.
    refreshCompletionStatus(routine);

    // 지금 저장해 id 를 받는다. 목록에만 넣으면 커밋 때에야 id 가 매겨져, 그림 예약·정산에 넘길 카드 id 가
    // 비어 있다 — 예전에는 그래서 그림 채우기가 "카드 없음"으로 끝났다.
    routineStepRepository.save(step);

    // 직접 사진 방식(#457): 그림 요청 여부와 무관하게 예약도 채우기 예약도 하지 않는다. 그림 몫 크레딧을
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
    routineStepImageFiller.scheduleAfterCommit(
      caller.memberId(), routineId, step.getId(), NicknamePlaceholder.mask(step.getDescription(), nickname),
      routine.getProfile().getCharacter(),
      FluxSeed.routineKey(routine.getProfile().getId(), routine.getTitle()), creditJobId,
      routine.getProfile().getImageStyle());

    return RoutineResponse.from(routine);
  }

  /**
   * 카드가 늘거나 줄었을 때 일과의 완료 상태를 다시 계산한다 (이슈 #199).
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

  /**
   * 홈 목록의 순서를 통째로 다시 매긴다.
   *
   * <p>보낸 차례대로 1부터 번호를 붙인다. 일부만 보내 부분 갱신하는 방식이 아니라
   * <b>화면에 보이는 전체를 그대로 보낸다</b> — 부분 갱신은 두 사람이 동시에 순서를
   * 바꿀 때 뒤엉킨다.
   *
   * <p>하나라도 남의 것이거나 없는 것이 섞이면 <b>아무것도 바꾸지 않고</b> 거부한다.
   * 절반만 반영되면 화면과 서버의 순서가 어긋나 더 나쁘다.
   *
   * <p>그사이 목록이 늘거나 줄었으면 409 다 (다중 보호자 E24). 보호자가 여럿이면(또는 한 보호자가 휴대폰
   * 둘로) 옛 목록을 보고 동시에 순서를 보낼 수 있다. 비교 기준은 앱이 실제로 보내는 목록 — 보호자 홈의
   * 오늘 목록(단계가 있는 것)이다.
   */
  @Transactional
  public void reorder(Caller caller, List<String> routineIds) {
    if (routineIds == null || routineIds.isEmpty()) {
      return;
    }
    // 같은 값이 두 번 오면 번호가 겹쳐 순서가 뒤엉킨다.
    if (new HashSet<>(routineIds).size() != routineIds.size()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }

    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);
    List<Routine> routines = routineRepository.findAllById(routineIds);
    // 보낸 일과가 그사이 지워졌다 — 화면이 옛 목록이다.
    if (routines.size() != routineIds.size()) {
      throw new CustomException(ErrorCode.ROUTINE_ORDER_CONFLICT);
    }

    Map<String, Routine> byId = new HashMap<>();
    for (Routine routine : routines) {
      if (!routine.getProfile().getId().equals(profile.getId())) {
        throw new CustomException(ErrorCode.ROUTINE_ACCESS_DENIED);
      }
      byId.put(routine.getId(), routine);
    }
    // 그사이 오늘 일과가 늘었다 — 보낸 목록으로는 새 일과의 자리를 알 수 없다.
    if (hasTodayRoutineMissingFrom(profile.getId(), byId.keySet())) {
      throw new CustomException(ErrorCode.ROUTINE_ORDER_CONFLICT);
    }

    for (int i = 0; i < routineIds.size(); i++) {
      byId.get(routineIds.get(i)).setDisplayOrder(i + 1);
    }
  }

  /**
   * 지금 오늘 목록에 있는데 보낸 목록에 없는 일과가 있는가.
   *
   * <p>앱은 오늘 목록 중 단계가 있는 것만 보내고, 방금 저장한 일과를 앞에 더해 보낸다
   * (today_routine_section.dart homeRoutinesProvider). 같은 기준으로 세야 멀쩡한 요청을 409 로 막지 않는다
   * — 보낸 목록에만 있는 일과는 문제가 아니다.
   */
  private boolean hasTodayRoutineMissingFrom(String profileId, Set<String> sent) {
    LocalDate today = LocalDate.now();
    return routineRepository.findTodayOrdered(
        profileId, List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED),
        today.atStartOfDay(), today.atTime(LocalTime.MAX))
      .stream()
      .filter(routine -> !routine.getSteps().isEmpty())
      .anyMatch(routine -> !sent.contains(routine.getId()));
  }

  /**
   * 일과 안의 행동 단계 순서를 바꾼다.
   *
   * <p>{@link #reorder}(일과 순서)와 같은 방식이다 — <b>화면에 보이는 전체를 그대로
   * 받아 통째로 다시 매긴다.</b> 부분 갱신은 두 곳에서 동시에 바꿀 때 뒤엉킨다.
   *
   * <p><b>하나라도 어긋나면 아무것도 바꾸지 않는다.</b> 절반만 반영되면 화면과 서버가
   * 어긋나 더 나쁘다 — 보호자는 자기가 바꾼 순서를 봤는데 이룸이 휴대폰에는 다른
   * 차례로 뜬다.
   */
  @Transactional
  public void reorderSteps(Caller caller, String routineId, List<String> stepIds) {
    if (stepIds == null || stepIds.isEmpty()) {
      return;
    }
    // 같은 값이 두 번 오면 번호가 겹쳐 순서가 뒤엉킨다.
    if (new HashSet<>(stepIds).size() != stepIds.size()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }

    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    List<RoutineStep> steps = routine.getSteps();

    // 일부만 보내면 빠진 단계의 차례가 어디인지 알 수 없다. 전체가 와야 한다.
    if (steps.size() != stepIds.size()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }

    Map<String, RoutineStep> byId = new HashMap<>();
    for (RoutineStep step : steps) {
      byId.put(step.getId(), step);
    }
    // 남의 일과 단계나 없는 단계가 섞이면 멈춘다.
    for (String stepId : stepIds) {
      if (!byId.containsKey(stepId)) {
        throw new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND);
      }
    }

    for (int i = 0; i < stepIds.size(); i++) {
      byId.get(stepIds.get(i)).setStepOrder(i + 1);
    }
  }

  private Routine getRoutineFor(Caller caller, String routineId, RoutineAction action) {
    return RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId, action);
  }
}
