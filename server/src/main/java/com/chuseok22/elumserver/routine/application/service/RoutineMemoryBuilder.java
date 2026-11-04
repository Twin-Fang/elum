package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineMemoryAi;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * AI 메모 갱신 한 주기 (#1082): 대기 이룸이 > 이룸이마다 준비 > AI 호출 > 반영
 * 일과 만들기·확정과 따로 도는 예약 작업이라 실패해도 사용자 동작을 막지 않음. 이룸이 하나의 실패는 그 이룸이만 건너뜀
 * 트랜잭션을 여기 두지 않음 (AI 호출 동안 커넥션을 잡지 않고, 이룸이마다 따로 커밋)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RoutineMemoryBuilder {

  /// 한 주기에 갱신하는 최대 이룸이 수 (남은 이룸이는 다음 주기)
  static final int MAX_PROFILES_PER_RUN = 50;

  private final RoutineMemoryBuildStore routineMemoryBuildStore;
  private final RoutineMemoryAi routineMemoryAi;
  private final AiDailyBudgetGuard aiDailyBudgetGuard;

  /// 한 주기: 갱신한 이룸이 수, 실패 수
  public RunResult runOnce() {
    List<String> profileIds;
    try {
      profileIds = routineMemoryBuildStore.findPendingProfileIds();
    } catch (RuntimeException e) {
      log.error("[routine memory] pending lookup failed, retry next run", e);
      return new RunResult(0, 0);
    }
    int built = 0;
    int failed = 0;
    for (String profileId : profileIds.stream().limit(MAX_PROFILES_PER_RUN).toList()) {
      // 하루 AI 비용 상한에 닿으면 이번 주기는 멈춤 (일과 만들기가 우선)
      if (aiDailyBudgetGuard.isReached()) {
        log.info("[routine memory] daily ai budget reached, stopping run : built={}", built);
        break;
      }
      switch (buildProfile(profileId)) {
        case BUILT -> built++;
        case FAILED -> failed++;
        case SKIPPED -> { }
      }
    }
    if (built > 0 || failed > 0) {
      log.info("[routine memory] run done : candidates={}, built={}, failed={}", profileIds.size(), built, failed);
    }
    return new RunResult(built, failed);
  }

  /// 이룸이 하나: 준비 > (작업 있으면) AI > 반영. 던지지 않음
  Outcome buildProfile(String profileId) {
    RoutineMemoryBuildStore.BuildJob job;
    try {
      job = routineMemoryBuildStore.prepare(profileId);
    } catch (RuntimeException e) {
      log.warn("[routine memory] prepare failed : profileId={}", profileId, e);
      return Outcome.FAILED;
    }
    if (job == null) {
      return Outcome.SKIPPED;
    }
    // 호출 기록에 보호자·언어를 달아 비용이 그 계정으로 잡히게 (finally 에서 비움)
    AiCallContext.setMemberId(job.memberId());
    AiCallContext.setContentLocale(job.locale());
    try {
      List<String> lines = routineMemoryAi.buildLines(job.input());
      routineMemoryBuildStore.apply(job, lines);
      return Outcome.BUILT;
    } catch (RuntimeException e) {
      log.warn("[routine memory] build failed, retry after interval : profileId={}", profileId, e);
      recordFailureQuietly(profileId);
      return Outcome.FAILED;
    } finally {
      AiCallContext.clear();
    }
  }

  private void recordFailureQuietly(String profileId) {
    try {
      routineMemoryBuildStore.recordFailure(profileId);
    } catch (RuntimeException e) {
      log.warn("[routine memory] failure record failed : profileId={}", profileId, e);
    }
  }

  enum Outcome {
    BUILT,
    SKIPPED,
    FAILED
  }

  public record RunResult(int built, int failed) {

  }
}
