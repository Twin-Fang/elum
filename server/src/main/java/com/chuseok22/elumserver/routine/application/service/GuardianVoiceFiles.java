package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.GuardianVoiceStorage;
import java.util.Collection;
import java.util.List;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * 보호자 목소리 파일 정리: 롤백 시 새 파일 삭제, 커밋 후 아무 카드도 안 가리키는 파일 삭제, 탈퇴 시 보호자 폴더 삭제 (#787)
 * 지우기 실패는 던지지 않음 (본 작업은 이미 끝남, 기록만)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class GuardianVoiceFiles {

  private final GuardianVoiceStorage guardianVoiceStorage;
  private final RoutineStepRepository routineStepRepository;

  /**
   * 일과 카드들의 녹음 열쇠 (null 제외, 중복 제거)
   */
  public static List<String> voiceKeysOf(Routine routine) {
    return voiceKeysOf(routine.getSteps());
  }

  public static List<String> voiceKeysOf(Collection<RoutineStep> steps) {
    return steps.stream().map(RoutineStep::getGuardianVoicePath).filter(Objects::nonNull).distinct().toList();
  }

  /**
   * 롤백되면 방금 저장한 파일 삭제 (아무도 안 가리키는 파일이 쌓이지 않게)
   */
  public void deleteOnRollback(String newKey) {
    if (!TransactionSynchronizationManager.isSynchronizationActive()) {
      return;
    }
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
      @Override
      public void afterCompletion(int status) {
        if (status == STATUS_ROLLED_BACK) {
          guardianVoiceStorage.delete(newKey);
        }
      }
    });
  }

  /**
   * 커밋 후 열쇠마다: 다른 카드가 아직 가리키면 남김, 아니면 파일 삭제 (트랜잭션 밖이면 바로)
   */
  public void deleteUnreferencedAfterCommit(Collection<String> keys) {
    List<String> targets = keys.stream().filter(key -> key != null && !key.isBlank()).distinct().toList();
    if (targets.isEmpty()) {
      return;
    }
    runAfterCommit(() -> targets.forEach(this::deleteIfUnreferenced));
  }

  /**
   * 커밋 후 보호자 녹음 전체 삭제 (탈퇴·완전 삭제). 롤백이면 그대로 둠
   */
  public void deleteAllOfAfterCommit(String memberId) {
    runAfterCommit(() -> guardianVoiceStorage.deleteAllOf(memberId));
  }

  private void deleteIfUnreferenced(String key) {
    try {
      if (routineStepRepository.existsByGuardianVoicePath(key)) {
        return;
      }
      guardianVoiceStorage.delete(key);
    } catch (RuntimeException e) {
      log.warn("[guardian voice] cleanup failed : key={}", key, e);
    }
  }

  private static void runAfterCommit(Runnable action) {
    if (!TransactionSynchronizationManager.isSynchronizationActive()) {
      action.run();
      return;
    }
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
      @Override
      public void afterCommit() {
        action.run();
      }
    });
  }
}
