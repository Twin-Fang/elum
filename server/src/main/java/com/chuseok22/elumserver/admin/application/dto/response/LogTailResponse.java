package com.chuseok22.elumserver.admin.application.dto.response;

public record LogTailResponse(
  boolean exists,
  long nextOffset,
  String content
) {

  public static LogTailResponse notFound() {
    return new LogTailResponse(false, 0, "");
  }
}
