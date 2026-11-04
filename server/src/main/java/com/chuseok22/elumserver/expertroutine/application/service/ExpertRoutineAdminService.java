package com.chuseok22.elumserver.expertroutine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.expertroutine.application.dto.request.ExpertRoutineInput;
import com.chuseok22.elumserver.expertroutine.application.dto.request.ExpertRoutineInput.StepInput;
import com.chuseok22.elumserver.expertroutine.core.ExpertRoutineNameScrubber;
import com.chuseok22.elumserver.expertroutine.core.ExpertRoutineReviewStatus;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutine;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutineStep;
import com.chuseok22.elumserver.expertroutine.infrastructure.repository.ExpertRoutineRepository;
import com.chuseok22.elumserver.expertroutine.infrastructure.repository.ExpertRoutineStepRepository;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot.StepSnapshot;
import com.chuseok22.elumserver.routine.application.service.RoutineShareService;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import java.util.ArrayList;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 관리자 전문가 일과: 목록, 만들기·고치기(검증 > 카드 통째 바꾸기), 공개·내리기, 지우기, 보호자 일과에서 초안 만들기
 * 검증 실패는 EXPERT_ROUTINE_INVALID + 이유(detail, ExpertRoutineInputRules) > 관리자 화면이 문구로 바꿈
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ExpertRoutineAdminService {

  // 보호자 일과에서 만든 초안의 분류 (관리자가 고침)
  private static final TalkCategory DEFAULT_COPY_CATEGORY = TalkCategory.DAILY_FLOW;
  // 보호자 일과에서 만든 초안의 검수 메모
  private static final String COPY_REVIEW_NOTE = "보호자 일과에서 옮긴 초안. 이룸이 호칭은 자리표시로 바꿨고 원문 입력·사진·AI 그림은 옮기지 않았어요."
    + " 다른 사람 이름·장소가 남았는지 확인해 주세요.";

  private final ExpertRoutineRepository expertRoutineRepository;
  private final ExpertRoutineStepRepository expertRoutineStepRepository;
  private final ExpertRoutineInputRules expertRoutineInputRules;
  private final RoutineShareService routineShareService;

  @Transactional(readOnly = true)
  public List<ExpertRoutine> listAll() {
    return expertRoutineRepository.findAllByOrderBySortOrderAscTitleAsc();
  }

  /**
   * @throws CustomException 없으면 EXPERT_ROUTINE_NOT_FOUND
   */
  @Transactional(readOnly = true)
  public ExpertRoutine get(String id) {
    return expertRoutineRepository.findById(id == null ? "" : id)
      .orElseThrow(() -> new CustomException(ErrorCode.EXPERT_ROUTINE_NOT_FOUND));
  }

  @Transactional(readOnly = true)
  public List<ExpertRoutineStep> stepsOf(String id) {
    return expertRoutineStepRepository.findByExpertRoutineIdOrderByStepOrderAsc(id);
  }

  /**
   * 새로 만들기: 검증 > 저장(공개 꺼짐) > 카드 저장
   *
   * @throws CustomException 입력 오류는 EXPERT_ROUTINE_INVALID (detail = 이유)
   */
  @Transactional
  public ExpertRoutine create(ExpertRoutineInput input, String adminName) {
    ExpertRoutineInputRules.Validated validated = expertRoutineInputRules.validate(input);
    ExpertRoutine routine = new ExpertRoutine();
    routine.setPublished(false);
    applyFields(routine, validated, adminName);
    ExpertRoutine saved = expertRoutineRepository.save(routine);
    replaceSteps(saved.getId(), validated.steps());
    log.info("[expert routine admin] created : id={}, stepCount={}", saved.getId(), saved.getStepCount());
    return saved;
  }

  /**
   * 고치기: 검증 > 칸 바꾸기 > 카드 통째 바꾸기 (초안으로 돌리면 공개도 꺼짐)
   *
   * @throws CustomException 없으면 EXPERT_ROUTINE_NOT_FOUND, 입력 오류는 EXPERT_ROUTINE_INVALID
   */
  @Transactional
  public ExpertRoutine update(String id, ExpertRoutineInput input, String adminName) {
    ExpertRoutine routine = get(id);
    ExpertRoutineInputRules.Validated validated = expertRoutineInputRules.validate(input);
    applyFields(routine, validated, adminName);
    if (routine.getReviewStatus() != ExpertRoutineReviewStatus.REVIEWED && routine.isPublished()) {
      routine.setPublished(false);
      log.info("[expert routine admin] unpublished : back to draft, id={}", id);
    }
    replaceSteps(routine.getId(), validated.steps());
    return routine;
  }

  /**
   * 공개·내리기: 공개는 검수 완료 + 카드 1장 이상일 때만
   *
   * @throws CustomException 초안 공개는 EXPERT_ROUTINE_INVALID (detail NOT_REVIEWED), 카드 없음 STEPS_REQUIRED
   */
  @Transactional
  public ExpertRoutine setPublished(String id, boolean isPublished, String adminName) {
    ExpertRoutine routine = get(id);
    if (isPublished && routine.getReviewStatus() != ExpertRoutineReviewStatus.REVIEWED) {
      throw new CustomException(ErrorCode.EXPERT_ROUTINE_INVALID, ExpertRoutineInputRules.REASON_NOT_REVIEWED);
    }
    if (isPublished && routine.getStepCount() == 0) {
      throw new CustomException(ErrorCode.EXPERT_ROUTINE_INVALID, ExpertRoutineInputRules.REASON_STEPS_REQUIRED);
    }
    routine.setPublished(isPublished);
    routine.setUpdatedBy(adminName);
    log.info("[expert routine admin] published changed : id={}, isPublished={}", id, isPublished);
    return routine;
  }

  /**
   * 지우기: 카드 > 일과 (가져간 보호자 일과는 사본이라 그대로)
   */
  @Transactional
  public void delete(String id) {
    ExpertRoutine routine = get(id);
    expertRoutineStepRepository.deleteByExpertRoutineId(routine.getId());
    expertRoutineRepository.delete(routine);
    log.info("[expert routine admin] deleted : id={}", id);
  }

  /**
   * 보호자 일과에서 초안 만들기: 스냅샷 > 호칭 지우기 > 번들 그림만 남기기 > 초안 저장(공개 꺼짐)
   * 옮기지 않는 것 4개: 원문 입력, 보호자 사진, AI 그림, 보상 (보상 글에 이름이 들어 있을 수 있음)
   *
   * @throws CustomException 없는 일과 ROUTINE_NOT_FOUND, 카드 없음·글이 너무 긺 EXPERT_ROUTINE_INVALID
   */
  @Transactional
  public ExpertRoutine createDraftFromRoutine(String routineId, String adminName) {
    RoutineShareSnapshot snapshot = routineShareService.snapshotForCatalog(routineId);
    List<StepInput> steps = new ArrayList<>();
    for (StepSnapshot step : snapshot.steps()) {
      String text = step.description() == null || step.description().isBlank() ? step.title() : step.description();
      steps.add(new StepInput(scrub(text, snapshot), step.pictogramId(), step.exampleImageId()));
    }
    ExpertRoutineInput input = new ExpertRoutineInput(scrub(snapshot.title(), snapshot), null,
      DEFAULT_COPY_CATEGORY.name(), snapshot.language().code(), null, null, null,
      ExpertRoutineReviewStatus.DRAFT.name(), COPY_REVIEW_NOTE, steps);
    ExpertRoutine draft = create(input, adminName);
    log.info("[expert routine admin] draft from routine : id={}, stepCount={}", draft.getId(), draft.getStepCount());
    return draft;
  }

  private static String scrub(String text, RoutineShareSnapshot snapshot) {
    return ExpertRoutineNameScrubber.scrub(text, snapshot.profileNickname(), snapshot.language());
  }

  private static void applyFields(ExpertRoutine routine, ExpertRoutineInputRules.Validated validated, String adminName) {
    routine.setTitle(validated.title());
    routine.setSummary(validated.summary());
    routine.setCategory(validated.category());
    routine.setLanguage(validated.language());
    routine.setRewardText(validated.rewardText());
    routine.setRewardPresetKey(validated.rewardPresetKey());
    routine.setSortOrder(validated.sortOrder());
    routine.setReviewStatus(validated.reviewStatus());
    routine.setReviewNote(validated.reviewNote());
    routine.setStepCount(validated.steps().size());
    routine.setUpdatedBy(adminName);
  }

  // 카드 통째 바꾸기 (순서는 0부터 다시 매김)
  private void replaceSteps(String expertRoutineId, List<StepInput> steps) {
    expertRoutineStepRepository.deleteByExpertRoutineId(expertRoutineId);
    List<ExpertRoutineStep> entities = new ArrayList<>();
    for (int index = 0; index < steps.size(); index++) {
      StepInput input = steps.get(index);
      ExpertRoutineStep step = new ExpertRoutineStep();
      step.setExpertRoutineId(expertRoutineId);
      step.setStepOrder(index);
      step.setText(input.text());
      step.setPictogramId(input.pictogramId());
      step.setExampleImageId(input.exampleImageId());
      entities.add(step);
    }
    expertRoutineStepRepository.saveAll(entities);
  }
}
