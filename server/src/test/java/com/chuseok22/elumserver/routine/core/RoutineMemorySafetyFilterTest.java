package com.chuseok22.elumserver.routine.core;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

/**
 * AI 메모 줄 안전 검사 (#1082, 원칙 1). 깨지면 진단·장애·정도 표현이 메모에 저장되고 매 일과 AI 로 나간다
 */
class RoutineMemorySafetyFilterTest {

  @ParameterizedTest
  @DisplayName("진단명·장애 유형·정도·능력 평가·연락처가 든 줄은 버린다")
  @ValueSource(strings = {
    "자폐가 있어 카드를 잘게 나눠요",
    "ADHD 라서 짧게 만들어요",
    "발달장애 아이라 쉬운 말을 써요",
    "중증이라 한 동작씩 나눠요",
    "인지 수준이 낮아 짧게 써요",
    "아이가 혼자서는 못해요",
    "약물 복용 뒤에 쉬어요",
    "엄마 번호 010-1234-5678 을 넣어요",
  })
  void rejectsForbidden(String line) {
    assertThat(RoutineMemorySafetyFilter.isAllowed(line)).isFalse();
  }

  @ParameterizedTest
  @DisplayName("카드 만드는 방식만 적은 줄은 그대로 둔다 (낱말 바꾸기·쪼개기·약 먹기 같은 일상 카드)")
  @ValueSource(strings = {
    "'손을 씻어요' 대신 '손을 닦아요'라고 써요",
    "옷 입기는 윗옷·바지·양말로 나눠요",
    "카드를 큼직하게 합쳐 적게 만들어요",
    "약 먹기 카드 뒤에 물 마시기를 넣어요",
  })
  void keepsCardStyleLines(String line) {
    assertThat(RoutineMemorySafetyFilter.isAllowed(line)).isTrue();
  }

  @org.junit.jupiter.api.Test
  @DisplayName("빈 줄과 60자 넘는 줄은 버린다 (프롬프트·화면 한도)")
  void rejectsBlankAndTooLong() {
    assertThat(RoutineMemorySafetyFilter.isAllowed("  ")).isFalse();
    assertThat(RoutineMemorySafetyFilter.isAllowed("가".repeat(61))).isFalse();
  }
}
