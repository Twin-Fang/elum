package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.LoggerLevelResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.regex.Pattern;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.logging.LogLevel;
import org.springframework.boot.logging.LoggerConfiguration;
import org.springframework.boot.logging.LoggingSystem;
import org.springframework.stereotype.Service;

/**
 * 재배포 없이 로거 레벨을 바꾼다. 바꾼 값은 이 JVM 에만 걸리고, 재배포하면 yml 값으로 돌아간다.
 * "원래대로"를 위해 처음 바꾸기 직전의 설정값을 기억한다.
 */
@Slf4j
@Service
public class AdminLogLevelService {

  static final List<String> KEY_LOGGERS = List.of(
    LoggingSystem.ROOT_LOGGER_NAME,
    "com.chuseok22",
    "org.springframework.web.servlet.DispatcherServlet",
    "org.hibernate.SQL",
    "org.hibernate.orm.jdbc.bind"
  );
  // 화면에서 직접 입력한 이름을 그대로 logback 에 넘기므로 자바 패키지 모양만 받는다.
  private static final Pattern LOGGER_NAME = Pattern.compile("^[A-Za-z_$][\\w$]*(\\.[A-Za-z_$][\\w$]*)*$");
  private static final int MAX_CHANGED_LOGGERS = 100;

  private final LoggingSystem loggingSystem;
  private final Map<String, Optional<LogLevel>> originals = new ConcurrentHashMap<>();

  public AdminLogLevelService(LoggingSystem loggingSystem) {
    this.loggingSystem = loggingSystem;
  }

  public List<LoggerLevelResponse> list() {
    Set<String> names = new LinkedHashSet<>(KEY_LOGGERS);
    originals.keySet().stream().sorted().forEach(names::add);
    return names.stream().map(this::describe).toList();
  }

  /** level 이 비면 처음 바꾸기 전 값으로 되돌린다. */
  public LoggerLevelResponse change(String logger, String level) {
    String name = validateName(logger);
    if (level == null || level.isBlank()) {
      Optional<LogLevel> original = originals.remove(name);
      if (original != null) {
        loggingSystem.setLogLevel(name, original.orElse(null));
        log.info("[관리자 로그] 로거 레벨 복구: logger={}, level={}", name, original.map(Enum::name).orElse("(상속)"));
      }
      return describe(name);
    }
    LogLevel target = parseLevel(level);
    if (!originals.containsKey(name) && originals.size() >= MAX_CHANGED_LOGGERS) {
      throw new CustomException(ErrorCode.INVALID_LOG_LEVEL);
    }
    originals.computeIfAbsent(name, key -> Optional.ofNullable(configured(key)));
    loggingSystem.setLogLevel(name, target);
    log.info("[관리자 로그] 로거 레벨 변경: logger={}, level={}", name, target);
    return describe(name);
  }

  private LoggerLevelResponse describe(String name) {
    LoggerConfiguration configuration = loggingSystem.getLoggerConfiguration(name);
    String configured = configuration == null || configuration.getConfiguredLevel() == null
      ? null : configuration.getConfiguredLevel().name();
    String effective = configuration == null || configuration.getEffectiveLevel() == null
      ? null : configuration.getEffectiveLevel().name();
    return new LoggerLevelResponse(name, configured, effective, originals.containsKey(name));
  }

  private LogLevel configured(String name) {
    LoggerConfiguration configuration = loggingSystem.getLoggerConfiguration(name);
    return configuration == null ? null : configuration.getConfiguredLevel();
  }

  private String validateName(String logger) {
    if (logger == null || logger.isBlank()) {
      throw new CustomException(ErrorCode.INVALID_LOG_LEVEL);
    }
    String name = logger.trim();
    if (LoggingSystem.ROOT_LOGGER_NAME.equalsIgnoreCase(name)) {
      return LoggingSystem.ROOT_LOGGER_NAME;
    }
    if (!LOGGER_NAME.matcher(name).matches()) {
      throw new CustomException(ErrorCode.INVALID_LOG_LEVEL);
    }
    return name;
  }

  private LogLevel parseLevel(String level) {
    try {
      return LogLevel.valueOf(level.trim().toUpperCase(Locale.ROOT));
    } catch (IllegalArgumentException e) {
      throw new CustomException(ErrorCode.INVALID_LOG_LEVEL);
    }
  }
}
