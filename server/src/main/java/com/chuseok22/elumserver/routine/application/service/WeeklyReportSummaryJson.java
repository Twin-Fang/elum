package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.common.infrastructure.logging.LogTextLength;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import lombok.extern.slf4j.Slf4j;

/**
 * 정리 글 줄 칸 변환: 줄 목록 <-> JSON 문자열
 * 읽기 실패는 빈 목록 (망가진 한 행 때문에 리포트가 멈추지 않게, 빈 목록이면 호출부가 다시 만듦)
 */
@Slf4j
final class WeeklyReportSummaryJson {

  private static final ObjectMapper OBJECT_MAPPER = DefaultJsonMapper.SHARED;

  private WeeklyReportSummaryJson() {
  }

  static String write(List<String> lines) {
    try {
      return OBJECT_MAPPER.writeValueAsString(lines);
    } catch (JsonProcessingException e) {
      throw new IllegalStateException("weekly report summary lines serialization failed", e);
    }
  }

  static List<String> read(String json) {
    if (json == null || json.isBlank()) {
      return List.of();
    }
    try {
      return OBJECT_MAPPER.readValue(json, new TypeReference<List<String>>() { });
    } catch (JsonProcessingException e) {
      log.warn("[weekly report] unreadable stored lines : length={}", LogTextLength.of(json));
      return List.of();
    }
  }
}
