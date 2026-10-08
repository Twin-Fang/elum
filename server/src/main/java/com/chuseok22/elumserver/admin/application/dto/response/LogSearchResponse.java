package com.chuseok22.elumserver.admin.application.dto.response;

import java.util.List;

/**
 * @param scanned 파일에서 읽은 항목 수
 * @param matched 조건에 맞은 전체 항목 수 — entries 는 그중 최신 limit 건
 */
public record LogSearchResponse(
  String path,
  long scanned,
  long matched,
  List<Entry> entries
) {

  /** 시각·레벨이 없는 항목은 파일 첫머리에 끼인 줄이다. */
  public record Entry(
    String timestamp,
    String level,
    String text,
    boolean truncated
  ) {

  }
}
