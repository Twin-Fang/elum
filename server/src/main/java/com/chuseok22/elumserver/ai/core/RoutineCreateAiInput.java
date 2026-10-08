package com.chuseok22.elumserver.ai.core;

import com.fasterxml.jackson.annotation.JsonInclude;
import java.util.List;

// GEMINI_ROUTINE_CREATE_PREFIX 시스템 프롬프트가 기대하는 User Content 형식. 필드 이름은
// 프롬프트 본문의 [입력 형식] 절과 정확히 일치해야 한다.
public record RoutineCreateAiInput(
  String task,
  String routineText,
  ChildProfileInput childProfile,
  List<String> additionalAnswers,
  // 카드마다 고를 수 있는 무료 픽토그램 id 목록. 고르는 지시는 프롬프트(운영 DB 값이라 배포로 안 바뀐다)가
  // 아니라 스키마의 pictogramId description 에 있다. 카탈로그가 비었으면 필드째 빠진다.
  @JsonInclude(JsonInclude.Include.NON_EMPTY)
  List<String> pictogramCatalog
) {

}
