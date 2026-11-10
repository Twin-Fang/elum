package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.PictogramSet;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.infrastructure.entity.ImageStyle;
import com.chuseok22.elumserver.routine.application.dto.request.CardSplitRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.core.RoutineStepLimits;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 카드 나누기의 DB 쓰기·읽기: 나눌 카드 읽기(권한 확인), 그 카드를 새 카드 2~3장으로 교체
 * AI 호출은 여기서 하지 않음 > 트랜잭션이 DB 커넥션을 붙잡고 AI 를 기다리지 않게 CardSplitService 가 밖에서 호출
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class CardSplitStepWriter {

  private final RoutineRepository routineRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final RoutineStepRepository routineStepRepository;
  private final RoutineStepSpeechQueue routineStepSpeechQueue;
  private final GuardianVoiceFiles guardianVoiceFiles;

  /// 나눌 카드와 AI·그림 고르기에 필요한 맥락 (엔티티 밖으로 값만 내보냄)
  record SplitSource(
    String title, String description, String nickname, AppLocale language, PictogramSet pictogramSet
  ) {

  }

  /// 카드 한 장 읽기: 카드 수정과 같은 권한(EDIT) 확인 > 카드 찾기. 다 끝난 카드는 나눌 수 없음
  SplitSource readSource(Caller caller, String routineId, String stepId) {
    Routine routine = RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId, RoutineAction.EDIT);
    RoutineStep step = findStep(routine, stepId);
    if (Boolean.TRUE.equals(step.getCompleted())) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_ALREADY_COMPLETED);
    }
    return new SplitSource(
      step.getTitle() == null ? "" : step.getTitle(), step.getDescription() == null ? "" : step.getDescription(),
      routine.getProfile().getNickname(), languageOf(routine),
      ImageStyle.orDefault(routine.getProfile().getImageStyle()).pictogramSet());
  }

  /// 카드 교체 (한 트랜잭션): 새 카드를 그 자리에 순서대로 > 뒤 카드 순서 밀기 > 원래 카드 삭제 > 소리 예약
  @Transactional
  public RoutineResponse replaceStep(
    Caller caller, String routineId, String stepId, List<CardSplitRequest.Card> cards, List<String> pictogramIds
  ) {
    Routine routine = RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId, RoutineAction.EDIT);
    List<RoutineStep> steps = routine.getSteps();
    RoutineStep target = findStep(routine, stepId);
    if (Boolean.TRUE.equals(target.getCompleted())) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_ALREADY_COMPLETED);
    }
    if (steps.size() - 1 + cards.size() > RoutineStepLimits.MAX_STEP_COUNT) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_MAX_COUNT);
    }

    // 뒤 카드 순서 밀기 (새 카드가 원래 카드 자리부터 차지)
    int targetOrder = target.getStepOrder();
    int shiftCount = cards.size() - 1;
    steps.stream().filter(step -> step.getStepOrder() > targetOrder)
      .forEach(step -> step.setStepOrder(step.getStepOrder() + shiftCount));

    // 새 카드 추가 (그림은 직접 더하기와 같이 무료 픽토그램만)
    List<RoutineStep> addedSteps = new ArrayList<>();
    for (int index = 0; index < cards.size(); index++) {
      RoutineStep added = new RoutineStep();
      added.setRoutine(routine);
      added.setTitle(cards.get(index).title().trim());
      added.setDescription(cards.get(index).description() == null ? "" : cards.get(index).description().trim());
      added.setPictogramId(pictogramIds.get(index));
      added.setStepOrder(targetOrder + index);
      added.setCompleted(false);
      steps.add(added);
      addedSteps.add(added);
    }

    // 원래 카드 삭제 (소리·보호자 녹음 정리) > 순서 1..N 정규화
    steps.remove(target);
    routineStepSpeechQueue.deleteStepsAfterCommit(List.of(target.getId()));
    guardianVoiceFiles.deleteUnreferencedAfterCommit(GuardianVoiceFiles.voiceKeysOf(List.of(target)));
    renumberSteps(steps);
    RoutineRules.clearExampleMark(routine);

    // 새 카드 id 를 받아 소리를 커밋 뒤에 만듦
    addedSteps.forEach(routineStepRepository::save);
    addedSteps.forEach(added -> routineStepSpeechQueue.enqueueAfterCommit(added.getId()));
    return RoutineResponse.from(routine);
  }

  private static RoutineStep findStep(Routine routine, String stepId) {
    return routine.getSteps().stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));
  }

  private static AppLocale languageOf(Routine routine) {
    return routine.getLanguage() == null ? AppLocale.KO : routine.getLanguage();
  }

  private static void renumberSteps(List<RoutineStep> steps) {
    List<RoutineStep> ordered = steps.stream().sorted(Comparator.comparingInt(RoutineStep::getStepOrder)).toList();
    for (int index = 0; index < ordered.size(); index++) {
      ordered.get(index).setStepOrder(index + 1);
    }
  }
}
