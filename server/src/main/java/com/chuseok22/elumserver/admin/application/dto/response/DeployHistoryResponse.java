package com.chuseok22.elumserver.admin.application.dto.response;

import java.time.OffsetDateTime;
import java.util.List;

public record DeployHistoryResponse(
  String currentInstance,
  List<Deployment> deployments
) {

  /**
   * @param status  RUNNING(실행 중) · STOPPED(종료) · FAILED(준비 전에 끝남) · STARTING(기동 중)
   * @param current 지금 이 화면에 응답하는 배포
   */
  public record Deployment(
    String instance,
    String version,
    String port,
    OffsetDateTime startedAt,
    OffsetDateTime readyAt,
    OffsetDateTime stoppedAt,
    String status,
    boolean current
  ) {

  }
}
