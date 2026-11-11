package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.routine.core.RoutineCardText;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Comparator;
import java.util.List;
import lombok.extern.slf4j.Slf4j;

/**
 * AI 처음 카드 사본 JSON 칸 변환: 카드 글 목록 <-> JSON 문자열
 * 읽기 실패는 빈 목록 (망가진 한 행 때문에 일과 만들기·화면이 멈추지 않게)
 */
@Slf4j
final class RoutineMemoryJson {

  private static final ObjectMapper OBJECT_MAPPER = DefaultJsonMapper.SHARED;
  private static final String EMPTY_ARRAY = "[]";

  private RoutineMemoryJson() {
  }

  static List<RoutineCardText> readCards(String json) {
    return read(json, new TypeReference<List<RoutineCardText>>() { }, "cards");
  }

  static String writeCards(List<RoutineCardText> cards) {
    return write(cards);
  }

  /// 지금 일과 단계 > 카드 글 목록 (차례순)
  static List<RoutineCardText> cardsOf(List<RoutineStep> steps) {
    return steps.stream()
      .sorted(Comparator.comparing(RoutineStep::getStepOrder))
      .map(step -> new RoutineCardText(step.getTitle(), step.getDescription()))
      .toList();
  }

  private static <T> List<T> read(String json, TypeReference<List<T>> type, String what) {
    if (json == null || json.isBlank()) {
      return List.of();
    }
    try {
      List<T> values = OBJECT_MAPPER.readValue(json, type);
      return values == null ? List.of() : values.stream().filter(value -> value != null).toList();
    } catch (JsonProcessingException e) {
      log.warn("[routine memory] unreadable json, treating as empty : field={}", what);
      return List.of();
    }
  }

  private static String write(Object value) {
    try {
      return OBJECT_MAPPER.writeValueAsString(value);
    } catch (JsonProcessingException e) {
      log.warn("[routine memory] json write failed, storing empty");
      return EMPTY_ARRAY;
    }
  }
}
