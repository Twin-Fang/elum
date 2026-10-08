package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.admin.application.dto.response.LoggerLevelResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.logging.LogLevel;
import org.springframework.boot.logging.LoggingSystem;

class AdminLogLevelServiceTest {

  private static final String LOGGER = "test.elum.admin.levels";

  private LoggingSystem loggingSystem;
  private AdminLogLevelService service;

  @BeforeEach
  void setUp() {
    loggingSystem = LoggingSystem.get(getClass().getClassLoader());
    loggingSystem.setLogLevel(LOGGER, LogLevel.WARN);
    service = new AdminLogLevelService(loggingSystem);
  }

  @AfterEach
  void tearDown() {
    loggingSystem.setLogLevel(LOGGER, null);
  }

  @Test
  @DisplayName("레벨을 바꾸면 바로 반영되고, 비우면 처음 설정값으로 돌아간다")
  void changeAndReset() {
    LoggerLevelResponse changed = service.change(LOGGER, "debug");

    assertThat(changed.configuredLevel()).isEqualTo("DEBUG");
    assertThat(changed.changed()).isTrue();
    assertThat(service.list()).extracting(LoggerLevelResponse::name).contains(LOGGER);

    service.change(LOGGER, "ERROR");
    LoggerLevelResponse reset = service.change(LOGGER, null);

    assertThat(reset.configuredLevel()).isEqualTo("WARN");
    assertThat(reset.changed()).isFalse();
  }

  @Test
  @DisplayName("주요 로거는 항상 목록에 있다")
  void listsKeyLoggers() {
    assertThat(service.list()).extracting(LoggerLevelResponse::name)
      .containsAll(AdminLogLevelService.KEY_LOGGERS);
  }

  @Test
  @DisplayName("이상한 이름·레벨은 INVALID_LOG_LEVEL")
  void rejectsInvalid() {
    assertThatThrownBy(() -> service.change(LOGGER, "LOUD"))
      .extracting("errorCode").isEqualTo(ErrorCode.INVALID_LOG_LEVEL);
    assertThatThrownBy(() -> service.change("../etc", "INFO"))
      .extracting("errorCode").isEqualTo(ErrorCode.INVALID_LOG_LEVEL);
    assertThatThrownBy(() -> service.change(" ", "INFO"))
      .extracting("errorCode").isEqualTo(ErrorCode.INVALID_LOG_LEVEL);
  }
}
