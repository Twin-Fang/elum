package com.chuseok22.elumserver.expertroutine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.expertroutine.application.dto.response.ExpertRoutineDetailResponse;
import com.chuseok22.elumserver.expertroutine.application.dto.response.ExpertRoutineDetailResponse.StepResponse;
import com.chuseok22.elumserver.expertroutine.application.dto.response.ExpertRoutineSummaryResponse;
import com.chuseok22.elumserver.expertroutine.core.ExpertRoutineReviewStatus;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutine;
import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutineStep;
import com.chuseok22.elumserver.expertroutine.infrastructure.repository.ExpertRoutineRepository;
import com.chuseok22.elumserver.expertroutine.infrastructure.repository.ExpertRoutineStepRepository;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 앱 전문가 일과 읽기: 목록(언어·분류), 미리 보기, 보이는 일과 찾기(가져오기가 씀)
 * 보이는 조건 2개(공개 + 검수 완료) 밖의 일과는 없는 것과 같은 404
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ExpertRoutineQueryService {

  // 목록 그림으로 쓰는 카드 순서 (첫 카드)
  private static final int COVER_STEP_ORDER = 0;

  private final ExpertRoutineRepository expertRoutineRepository;
  private final ExpertRoutineStepRepository expertRoutineStepRepository;

  /**
   * 목록: 분류 확인 > 언어 정하기(요청 값 > 요청 언어) > 보이는 일과 > 첫 카드 그림 붙이기
   *
   * @throws CustomException 모르는 분류는 INVALID_INPUT_VALUE
   */
  @Transactional(readOnly = true)
  public List<ExpertRoutineSummaryResponse> list(String rawCategory, String rawLanguage, AppLocale requestLocale) {
    TalkCategory category = rawCategory == null || rawCategory.isBlank() ? null : TalkCategory.parse(rawCategory);
    AppLocale language = AppLocale.findByCode(rawLanguage == null ? null : rawLanguage.trim()).orElse(requestLocale);
    List<ExpertRoutine> routines = category == null
      ? expertRoutineRepository.findByIsPublishedTrueAndReviewStatusAndLanguageOrderBySortOrderAscTitleAsc(
      ExpertRoutineReviewStatus.REVIEWED, language)
      : expertRoutineRepository.findByIsPublishedTrueAndReviewStatusAndLanguageAndCategoryOrderBySortOrderAscTitleAsc(
        ExpertRoutineReviewStatus.REVIEWED, language, category);
    Map<String, ExpertRoutineStep> coverById = coversOf(routines);
    return routines.stream().map(routine -> toSummary(routine, coverById.get(routine.getId()))).toList();
  }

  /**
   * 미리 보기: 보이는 일과 > 카드 전부
   *
   * @throws CustomException 내렸거나 없는 일과는 EXPERT_ROUTINE_NOT_FOUND
   */
  @Transactional(readOnly = true)
  public ExpertRoutineDetailResponse detail(String expertRoutineId) {
    ExpertRoutine routine = requireVisible(expertRoutineId);
    List<StepResponse> steps = stepsOf(routine.getId()).stream()
      .map(step -> new StepResponse(step.getStepOrder(), step.getText(), step.getPictogramId(), step.getExampleImageId()))
      .toList();
    return new ExpertRoutineDetailResponse(routine.getId(), routine.getTitle(), routine.getSummary(),
      routine.getCategory().name(), routine.getLanguage().code(), routine.getRewardText(), routine.getRewardPresetKey(),
      steps);
  }

  /**
   * 앱에 보이는 일과 (공개 + 검수 완료)
   *
   * @throws CustomException 없거나 안 보이는 일과는 EXPERT_ROUTINE_NOT_FOUND
   */
  @Transactional(readOnly = true)
  public ExpertRoutine requireVisible(String expertRoutineId) {
    return expertRoutineRepository.findById(expertRoutineId == null ? "" : expertRoutineId)
      .filter(ExpertRoutine::isVisibleInApp)
      .orElseThrow(() -> {
        log.info("[expert routine] rejected 404 : not visible, id={}", expertRoutineId);
        return new CustomException(ErrorCode.EXPERT_ROUTINE_NOT_FOUND);
      });
  }

  /// 카드 전부 (순서대로)
  @Transactional(readOnly = true)
  public List<ExpertRoutineStep> stepsOf(String expertRoutineId) {
    return expertRoutineStepRepository.findByExpertRoutineIdOrderByStepOrderAsc(expertRoutineId);
  }

  // 일과 id > 첫 카드 (쿼리 1번)
  private Map<String, ExpertRoutineStep> coversOf(List<ExpertRoutine> routines) {
    if (routines.isEmpty()) {
      return Map.of();
    }
    List<String> ids = routines.stream().map(ExpertRoutine::getId).toList();
    return expertRoutineStepRepository.findByExpertRoutineIdInAndStepOrder(ids, COVER_STEP_ORDER).stream()
      .collect(Collectors.toMap(ExpertRoutineStep::getExpertRoutineId, Function.identity(), (first, second) -> first));
  }

  private static ExpertRoutineSummaryResponse toSummary(ExpertRoutine routine, ExpertRoutineStep cover) {
    return new ExpertRoutineSummaryResponse(routine.getId(), routine.getTitle(), routine.getSummary(),
      routine.getCategory().name(), routine.getLanguage().code(), routine.getStepCount(), routine.getRewardText(),
      cover == null ? null : cover.getPictogramId(), cover == null ? null : cover.getExampleImageId());
  }
}
