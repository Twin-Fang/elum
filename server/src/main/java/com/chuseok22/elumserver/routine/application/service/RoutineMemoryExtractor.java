package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineMemoryAi;
import java.util.List;

import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * AI 메모리 수정 찾기 한 건: 하루 AI 비용 확인 > 선점 > AI 호출 > 반영 (일과당 1회, 실패해도 재시도 없음, 예외 안 던짐)
 * 확정 직후 비동기·스케줄러 줍기 공통 경로, 트랜잭션 없음 (AI 호출 중 커넥션 점유 방지, 선점·반영 별도 커밋)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RoutineMemoryExtractor {

  private final RoutineMemoryExtractionStore routineMemoryExtractionStore;
  private final RoutineMemoryAi routineMemoryAi;
  private final AiDailyBudgetGuard aiDailyBudgetGuard;

  /// 일과 하나 찾기. 하루 AI 비용 상한이면 선점하지 않고 건너뜀 (놓친 것 줍기가 나중에 다시 봄)
  public void extract(String routineId) {
    if (aiDailyBudgetGuard.isReached()) {
      log.info("[routine memory] extraction skipped : routineId={}, reason=daily ai budget reached", routineId);
      return;
    }
    Optional<RoutineMemoryExtractionStore.ExtractionJob> job;
    try {
      job = routineMemoryExtractionStore.claim(routineId);
    } catch (RuntimeException e) {
      log.warn("[routine memory] claim failed : routineId={}", routineId, e);
      return;
    }
    job.ifPresent(this::callAiAndApply);
  }

  /// 놓친 일과 줍기 (스케줄러): 찾은 건수 반환
  public int extractMissed() {
    List<String> routineIds;
    try {
      routineIds = routineMemoryExtractionStore.findMissedRoutineIds();
    } catch (RuntimeException e) {
      log.error("[routine memory] missed lookup failed, retry next run", e);
      return 0;
    }
    routineIds.forEach(this::extract);
    return routineIds.size();
  }

  private void callAiAndApply(RoutineMemoryExtractionStore.ExtractionJob job) {
    // 호출 기록에 보호자·언어를 달아 비용이 그 계정으로 잡히게 (finally 에서 비움)
    AiCallContext.setMemberId(job.memberId());
    AiCallContext.setContentLocale(job.locale());
    try {
      RoutineMemoryAi.ExtractionResult result = routineMemoryAi.extract(job.input());
      routineMemoryExtractionStore.apply(job, result);
    } catch (RuntimeException e) {
      log.warn("[routine memory] extraction failed : routineId={}", job.routineId(), e);
      markFailedQuietly(job.routineId());
    } finally {
      AiCallContext.clear();
    }
  }

  private void markFailedQuietly(String routineId) {
    try {
      routineMemoryExtractionStore.markFailed(routineId);
    } catch (RuntimeException e) {
      log.warn("[routine memory] failure record failed : routineId={}", routineId, e);
    }
  }
}
