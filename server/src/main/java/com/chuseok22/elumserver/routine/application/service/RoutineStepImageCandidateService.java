package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepResponse;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 새 그림 후보 고르기: 후보 받기, 새 그림으로 바꾸기, 원래 그림 그대로(후보 버리기)
 * 모두 보호자(EDIT 권한)만 — 이룸이는 고른 그림(imagePath)만 받음. 크레딧은 그릴 때 이미 정산됨
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RoutineStepImageCandidateService {

  private final RoutineRepository routineRepository;
  private final RoutineStepRepository routineStepRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final RoutineImageStorage routineImageStorage;
  private final PlatformTransactionManager transactionManager;

  /// 후보 그림 바이트 (없으면 404 ROUTINE_STEP_IMAGE_CANDIDATE_NOT_FOUND)
  public RoutineImageStorage.ImageContent readCandidate(Caller caller, String routineId, String stepId) {
    String candidateKey = transaction().execute(status -> {
      String key = stepFor(caller, routineId, stepId).getImageCandidatePath();
      if (key == null) {
        throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_CANDIDATE_NOT_FOUND);
      }
      return key;
    });
    return routineImageStorage.read(candidateKey);
  }

  /**
   * 새 그림으로 바꾸기: 후보 확인(보낸 열쇠 = 지금 후보) > 카드 그림 교체·후보 비움·예시 표시 지움 > 옛 그림 정리
   * 다른 후보로 바뀌었거나 이미 골랐으면 404 (카드 그림 그대로)
   */
  public RoutineStepResponse applyCandidate(Caller caller, String routineId, String stepId, String candidateImagePath) {
    AppliedCandidate applied = transaction().execute(status -> {
      RoutineStep step = stepFor(caller, routineId, stepId);
      if (candidateImagePath == null || !Objects.equals(step.getImageCandidatePath(), candidateImagePath)) {
        log.info("[routine image candidate] rejected 404 : stale candidate, stepId={}", stepId);
        throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_CANDIDATE_NOT_FOUND);
      }
      String oldImagePath = step.getImagePath();
      step.setImagePath(candidateImagePath);
      step.setImageCandidatePath(null);
      // 보호자가 그림을 바꿈 > 예시 표시 지움
      RoutineRules.clearExampleMark(step.getRoutine());
      return new AppliedCandidate(RoutineStepResponse.from(step), oldImagePath);
    });
    deleteOldIfUnreferenced(applied.oldImagePath(), stepId);
    log.info("[routine image candidate] applied : routineId={}, stepId={}", routineId, stepId);
    return applied.response();
  }

  /// 원래 그림 그대로: 후보 비움 > 파일 삭제. 후보가 없어도 성공 (두 번 눌러도 같은 결과)
  public void discardCandidate(Caller caller, String routineId, String stepId) {
    String candidateKey = transaction().execute(status -> {
      RoutineStep step = stepFor(caller, routineId, stepId);
      String key = step.getImageCandidatePath();
      step.setImageCandidatePath(null);
      return key;
    });
    if (candidateKey != null) {
      routineImageStorage.delete(candidateKey);
      log.info("[routine image candidate] discarded : routineId={}, stepId={}", routineId, stepId);
    }
  }

  /// 권한 EDIT 로 일과를 읽고 그 카드 (없으면 ROUTINE_STEP_NOT_FOUND)
  private RoutineStep stepFor(Caller caller, String routineId, String stepId) {
    Routine routine = RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId, RoutineAction.EDIT);
    return routine.getSteps().stream()
      .filter(candidate -> candidate.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));
  }

  /// 옛 그림 정리: 그림 없던 카드면 할 일 없음, 복제 일과가 같은 열쇠를 쓰면 남김. 실패해도 요청은 성공 (경고만)
  private void deleteOldIfUnreferenced(String oldKey, String stepId) {
    if (oldKey == null) {
      return;
    }
    try {
      if (routineStepRepository.existsByImagePathAndIdNot(oldKey, stepId)) {
        return;
      }
      routineImageStorage.delete(oldKey);
    } catch (RuntimeException e) {
      log.warn("[routine image candidate] old picture not deleted : stepId={}, key={}", stepId, oldKey, e);
    }
  }

  private TransactionTemplate transaction() {
    return new TransactionTemplate(transactionManager);
  }

  private record AppliedCandidate(RoutineStepResponse response, String oldImagePath) {

  }
}
