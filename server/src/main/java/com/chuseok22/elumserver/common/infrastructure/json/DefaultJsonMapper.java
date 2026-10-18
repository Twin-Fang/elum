package com.chuseok22.elumserver.common.infrastructure.json;

import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * 서버 전역 JSON 파싱·직렬화 공통: 설정을 건드리지 않은 Jackson 2 기본 매퍼 하나
 * Spring 빈이 아님 (Boot 4.1 은 Jackson 3 기반 + MVC 설정 보호 + 필터·엔티티는 주입 불가)
 */
public final class DefaultJsonMapper {

  // 모듈·옵션을 더하지 않는다 (AI 응답 파싱 동작 고정: DefaultJsonMapperTest)
  // ObjectMapper 는 thread-safe 라 공유 가능. 생성 후 configure 호출 금지
  public static final ObjectMapper SHARED = new ObjectMapper();

  private DefaultJsonMapper() {
  }
}
