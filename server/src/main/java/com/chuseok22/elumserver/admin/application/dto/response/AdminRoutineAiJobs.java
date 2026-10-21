package com.chuseok22.elumserver.admin.application.dto.response;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 일과 상세 "이 일과의 AI 작업" 카드: 크레딧 작업 줄(최근 N건) + 호출 수·실패 수·비용 합계
 * 상태 3개: 불러옴, 작업 없음(jobs 비어 있음), 불러오기 실패(isLoadFailed). 작업 밖 호출(질문 등)은 포함하지 않음
 */
public record AdminRoutineAiJobs(
  boolean isLoadFailed,
  List<JobLine> jobs,
  boolean isTruncated,
  long callCount,
  long failureCount,
  double totalCostUsd
) {

  /// 화면 안내에 붙이는 에러 코드 (조회 실패)
  public static final String LOAD_FAILED_ERROR_CODE = "E-ADM-ROUTINE-001";

  /**
   * 작업 1건: 종류·상태 표시 이름, 카드·그림 수, 차감 크레딧, 실패 사유, 연결 호출 수·성공 수·비용(USD)
   */
  public record JobLine(
    String id,
    String kindLabel,
    String statusLabel,
    LocalDateTime startedAt,
    int cardCount,
    int imageCount,
    int charged,
    String failReason,
    long callCount,
    long successCount,
    double costUsd
  ) {

    public long failureCount() {
      return callCount - successCount;
    }
  }

  public AdminRoutineAiJobs {
    jobs = jobs == null ? List.of() : List.copyOf(jobs);
  }

  /// 작업 줄 > 합계를 더한 카드 (isTruncated: 조회 상한에 닿아 더 오래된 작업이 빠졌을 수 있음)
  public static AdminRoutineAiJobs of(List<JobLine> jobs, boolean isTruncated) {
    List<JobLine> safeJobs = jobs == null ? List.of() : jobs;
    return new AdminRoutineAiJobs(false, safeJobs, isTruncated,
      safeJobs.stream().mapToLong(JobLine::callCount).sum(),
      safeJobs.stream().mapToLong(JobLine::failureCount).sum(),
      safeJobs.stream().mapToDouble(JobLine::costUsd).sum());
  }

  /// 조회 실패 (카드에 안내와 에러 코드만, 일과 상세는 그대로)
  public static AdminRoutineAiJobs loadFailed() {
    return new AdminRoutineAiJobs(true, List.of(), false, 0, 0, 0);
  }

  public String loadFailedErrorCode() {
    return LOAD_FAILED_ERROR_CODE;
  }
}
