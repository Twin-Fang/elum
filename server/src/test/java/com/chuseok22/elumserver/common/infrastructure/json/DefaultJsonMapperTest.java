package com.chuseok22.elumserver.common.infrastructure.json;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.ai.core.RoutineStepDraft;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.MapperFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import java.time.LocalDate;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 결함: 공통 매퍼 설정이 바뀌면 AI 응답 파싱(미지 필드·대소문자·날짜)이 조용히 달라진다
class DefaultJsonMapperTest {

  private final ObjectMapper plainMapper = new ObjectMapper();

  @Test
  @DisplayName("공통 매퍼의 설정 플래그는 new ObjectMapper() 기본값과 같다")
  void sharedMapperHasPlainDefaults() {
    ObjectMapper shared = DefaultJsonMapper.SHARED;

    assertThat(shared.getDeserializationConfig().getDeserializationFeatures())
      .isEqualTo(plainMapper.getDeserializationConfig().getDeserializationFeatures());
    assertThat(shared.getSerializationConfig().getSerializationFeatures())
      .isEqualTo(plainMapper.getSerializationConfig().getSerializationFeatures());
    for (MapperFeature feature : MapperFeature.values()) {
      assertThat(shared.isEnabled(feature)).as(feature.name()).isEqualTo(plainMapper.isEnabled(feature));
    }
    assertThat(shared.getRegisteredModuleIds()).isEmpty();
    assertThat(shared.isEnabled(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)).isTrue();
    assertThat(shared.isEnabled(MapperFeature.ACCEPT_CASE_INSENSITIVE_PROPERTIES)).isFalse();
    assertThat(shared.isEnabled(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)).isTrue();
  }

  @Test
  @DisplayName("AI 응답에 모르는 필드가 있으면 파싱이 실패한다")
  void unknownPropertyFails() {
    String json = "{\"title\":\"t\",\"steps\":[],\"extra\":1}";

    assertThatThrownBy(() -> DefaultJsonMapper.SHARED.readValue(json, RoutineStepDraft.class))
      .isInstanceOf(JsonProcessingException.class);
    assertThatThrownBy(() -> plainMapper.readValue(json, RoutineStepDraft.class))
      .isInstanceOf(JsonProcessingException.class);
  }

  @Test
  @DisplayName("필드 이름 대소문자는 구분한다 (Title 은 title 이 아니다)")
  void propertyNamesAreCaseSensitive() {
    String json = "{\"Title\":\"t\",\"steps\":[]}";

    assertThatThrownBy(() -> DefaultJsonMapper.SHARED.readValue(json, RoutineStepDraft.class))
      .isInstanceOf(JsonProcessingException.class);
  }

  @Test
  @DisplayName("날짜 모듈이 없어 LocalDate 직렬화는 지원하지 않는다")
  void localDateIsNotSupportedWithoutModule() {
    assertThatThrownBy(() -> DefaultJsonMapper.SHARED.writeValueAsString(Map.of("day", LocalDate.of(2026, 10, 18))))
      .isInstanceOf(JsonProcessingException.class);
  }

  @Test
  @DisplayName("정상 응답은 그대로 읽고, 선택 필드가 빠져도 null 로 읽는다")
  void parsesWellFormedDraft() throws Exception {
    String json = "{\"title\":\"t\",\"steps\":[{\"order\":1,\"title\":\"a\",\"description\":\"b\"}]}";

    RoutineStepDraft draft = DefaultJsonMapper.SHARED.readValue(json, RoutineStepDraft.class);

    assertThat(draft.steps().get(0).pictogramId()).isNull();
    assertThat(DefaultJsonMapper.SHARED.writeValueAsString(Map.of("text", "안녕")))
      .isEqualTo(plainMapper.writeValueAsString(Map.of("text", "안녕")));
  }
}
