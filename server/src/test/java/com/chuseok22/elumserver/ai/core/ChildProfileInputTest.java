package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Set;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class ChildProfileInputTest {

  private final ObjectMapper objectMapper = new ObjectMapper();

  @Test
  @DisplayName("nickname과 supportGoals를 enum 이름 그대로 직렬화한다")
  void serialize_withNicknameAndGoals_containsEnumNames() throws Exception {
    ChildProfileInput input = new ChildProfileInput("하늘이", Set.of(SupportGoal.PREPARE_ITEMS));

    String json = objectMapper.writeValueAsString(input);

    assertThat(json).contains("\"nickname\":\"하늘이\"");
    assertThat(json).contains("\"supportGoals\":[\"PREPARE_ITEMS\"]");
  }

  @Test
  @DisplayName("nickname이 null이고 supportGoals가 비어있어도 필드는 그대로 포함된다")
  void serialize_emptyProfile_stillIncludesFields() throws Exception {
    ChildProfileInput input = new ChildProfileInput(null, Set.of());

    String json = objectMapper.writeValueAsString(input);

    assertThat(json).contains("\"nickname\":null");
    assertThat(json).contains("\"supportGoals\":[]");
  }
}
