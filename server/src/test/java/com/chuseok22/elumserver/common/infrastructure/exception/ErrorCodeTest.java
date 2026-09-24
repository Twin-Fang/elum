package com.chuseok22.elumserver.common.infrastructure.exception;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

/**
 * 다중 보호자 1단계에서 더한 에러 코드 (명세 4-2 · 7장).
 *
 * <p>상태 코드가 곧 앱의 분기다. 403 이어야 할 것이 404 로 나가면 앱이 "없는 일과"로 알고
 * 목록에서 지운다.
 */
class ErrorCodeTest {

  @Test
  @DisplayName("E27·E28 연결되지 않은 이룸이는 403, E29 이룸이가 없으면 404")
  void profileCodes_haveExpectedStatus() {
    assertThat(ErrorCode.PROFILE_ACCESS_DENIED.getStatus()).isEqualTo(HttpStatus.FORBIDDEN);
    assertThat(ErrorCode.PROFILE_NOT_FOUND.getStatus()).isEqualTo(HttpStatus.NOT_FOUND);
  }

  @Test
  @DisplayName("E30 남이 만든 일과는 403, E24 순서가 그사이 바뀌면 409")
  void routineCodes_haveExpectedStatus() {
    assertThat(ErrorCode.ROUTINE_NOT_CREATOR.getStatus()).isEqualTo(HttpStatus.FORBIDDEN);
    assertThat(ErrorCode.ROUTINE_ORDER_CONFLICT.getStatus()).isEqualTo(HttpStatus.CONFLICT);
  }

  @Test
  @DisplayName("새 문구는 '아이'라고 부르지 않는다 — 이룸이를 쓰는 당사자는 20대일 수 있다")
  void newMessages_followTermRules() {
    List<ErrorCode> added = List.of(ErrorCode.PROFILE_NOT_FOUND, ErrorCode.PROFILE_ACCESS_DENIED,
      ErrorCode.ROUTINE_NOT_CREATOR, ErrorCode.ROUTINE_ORDER_CONFLICT);
    assertThat(added).allSatisfy(code -> assertThat(code.getMessage()).doesNotContain("아이").endsWith("요."));
  }
}
