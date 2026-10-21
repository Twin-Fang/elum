package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineAiJobs;
import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineAiJobs.JobLine;
import com.chuseok22.elumserver.ai.application.dto.response.AiCreditJobCallSummary;
import com.chuseok22.elumserver.ai.application.service.AiCallLogQueryService;
import com.chuseok22.elumserver.credit.application.service.CreditJobQueryService;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import java.util.List;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 일과 상세 AI 작업 카드: 크레딧 작업 조회, 작업별 호출 요약 연결, 합계
 * 쿼리 2회 (작업 최근 50건 > 그 작업들의 호출 묶음 집계), 작업 수만큼 묻지 않음
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminRoutineAiJobService {

  private final CreditJobQueryService creditJobQueryService;
  private final AiCallLogQueryService aiCallLogQueryService;

  /// 일과 id > 작업 줄(최신순) + 호출 수·실패 수·비용 합계
  public AdminRoutineAiJobs loadAiJobsOf(String routineId) {
    List<AiCreditJob> jobs = creditJobQueryService.findRecentJobsOfRoutine(routineId);
    Map<String, AiCreditJobCallSummary> callSummaries =
      aiCallLogQueryService.summarizeCallsByCreditJob(jobs.stream().map(AiCreditJob::getId).toList());
    boolean isTruncated = jobs.size() >= CreditJobQueryService.MAX_JOBS_PER_ROUTINE;
    return AdminRoutineAiJobs.of(
      jobs.stream().map(job -> toJobLine(job, callSummaries.get(job.getId()))).toList(), isTruncated);
  }

  // 작업 + 호출 요약(없으면 0건) > 화면 줄
  private static JobLine toJobLine(AiCreditJob job, AiCreditJobCallSummary callSummary) {
    long callCount = callSummary == null ? 0 : callSummary.callCount();
    long successCount = callSummary == null ? 0 : callSummary.successCount();
    double costUsd = callSummary == null ? 0 : callSummary.totalCostUsd();
    return new JobLine(job.getId(),
      job.getKind() == null ? "-" : job.getKind().getLabel(),
      job.getStatus() == null ? "-" : job.getStatus().getLabel(),
      job.getStartedAt(), job.getCardCount(), job.getImageCount(), job.getCharged(), job.getFailReason(),
      callCount, successCount, costUsd);
  }
}
