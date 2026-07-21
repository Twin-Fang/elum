package com.chuseok22.elumserver.admin.application.dto.response;

public record AdminRoutineStatusCounts(
  long total,
  long pendingReview,
  long confirmed,
  long completed
) {

}
