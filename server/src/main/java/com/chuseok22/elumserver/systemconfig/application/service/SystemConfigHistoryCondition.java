package com.chuseok22.elumserver.systemconfig.application.service;

import java.time.LocalDateTime;

/**
 * 설정 변경 이력 검색 조건: 검색어, 키, 변경자, 기간(from 포함 ~ toExclusive 미포함)
 * 비어 있는(null) 조건은 걸지 않음
 */
public record SystemConfigHistoryCondition(
  String likePattern,
  String configKey,
  String changedBy,
  LocalDateTime from,
  LocalDateTime toExclusive
) {

  public static SystemConfigHistoryCondition none() {
    return new SystemConfigHistoryCondition(null, null, null, null, null);
  }
}
