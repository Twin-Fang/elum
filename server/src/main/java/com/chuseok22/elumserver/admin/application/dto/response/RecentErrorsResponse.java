package com.chuseok22.elumserver.admin.application.dto.response;

import java.time.Instant;
import java.util.List;

/** @param since 집계 시작 시각 — 메모리 집계라 서버가 다시 뜨면 0부터 센다 */
public record RecentErrorsResponse(
  int last24h,
  Instant since,
  List<Item> recent
) {

  public record Item(
    Instant time,
    String logger,
    String message,
    String exceptionClass
  ) {

  }
}
