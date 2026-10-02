package com.chuseok22.elumserver.common.infrastructure.exception;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.util.Locale;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.MessageSource;
import org.springframework.context.support.StaticMessageSource;

class ErrorMessagesStartupGuardTest {

  @AfterEach
  void tearDown() {
    ErrorMessages.resetStandardForTesting();
  }

  /** 모든 코드에 ko 문구가 있는 가짜. mutator 로 한두 코드만 깨뜨린다. */
  private static void install(java.util.function.BiFunction<ErrorCode, String, String> mutator) {
    StaticMessageSource source = new StaticMessageSource();
    for (ErrorCode code : ErrorCode.values()) {
      source.addMessage(code.name(), Locale.of("ko"), mutator.apply(code, "문구 " + code.name()));
    }
    MessageSource fake = source;
    ErrorMessages.overrideStandardForTesting(new ErrorMessages(fake));
  }

  @Test
  @DisplayName("실제 리소스로는 기동 검사가 예외 없이 끝난다")
  void realResources_passes() {
    ApplicationRunner runner = new ErrorMessagesStartupGuard();

    assertThatCode(() -> runner.run(null)).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("한 코드의 ko 문구가 비면 run() 이 기동을 막고 그 코드 이름을 알린다")
  void blankKoMessage_blocksStartup() {
    install((code, text) -> code == ErrorCode.ROUTINE_NOT_FOUND ? "" : text);

    assertThatThrownBy(() -> new ErrorMessagesStartupGuard().run(null))
      .isInstanceOf(IllegalStateException.class)
      .hasMessageContaining("ROUTINE_NOT_FOUND");
  }

  @Test
  @DisplayName("한 코드의 문구가 코드 이름과 같으면(리소스 누락 때 나가는 값) 기동을 막는다")
  void messageEqualsCodeName_blocksStartup() {
    install((code, text) -> code == ErrorCode.ROUTINE_NOT_FOUND ? code.name() : text);

    assertThatThrownBy(() -> new ErrorMessagesStartupGuard().run(null))
      .isInstanceOf(IllegalStateException.class)
      .hasMessageContaining("ROUTINE_NOT_FOUND");
  }

  @Test
  @DisplayName("문제 코드가 많으면 5개만 적고 나머지는 개수로 알린다")
  void manyProblems_areSummarized() {
    install((code, text) -> "");

    assertThatThrownBy(() -> new ErrorMessagesStartupGuard().run(null))
      .isInstanceOf(IllegalStateException.class)
      .hasMessageContaining("외 " + (ErrorCode.values().length - 5) + "개");
  }
}
