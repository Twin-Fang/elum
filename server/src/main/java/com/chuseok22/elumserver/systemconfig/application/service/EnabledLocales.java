package com.chuseok22.elumserver.systemconfig.application.service;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.Collections;
import java.util.EnumSet;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 일과를 만들 수 있는 언어.
 *
 * <p>ko 는 늘 켜져 있다 — 설정이 깨져도 일과 생성이 멈추지 않는다. 읽기는 관대하고(알 수 없는 코드는 건너뛴다)
 * 저장은 엄격하다({@link #normalize}).
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class EnabledLocales {

  private final SystemConfigService systemConfigService;

  /** 켜진 언어(ko 포함, enum 순서). 설정을 읽지 못하면 ko 만. */
  public Set<AppLocale> current() {
    try {
      return parse(systemConfigService.getString(ConfigKey.ENABLED_CONTENT_LOCALES));
    } catch (RuntimeException e) {
      log.warn("[EnabledLocales] 설정을 읽지 못해 ko 만 켜진 것으로 봅니다", e);
      return Collections.unmodifiableSet(EnumSet.of(AppLocale.KO));
    }
  }

  public boolean contains(AppLocale locale) {
    return current().contains(locale);
  }

  /**
   * 일과의 콘텐츠 언어. 요청 언어가 켜져 있으면 그것, 아니면 EN 이 켜져 있을 때 EN, 아니면 KO.
   * 검증되지 않은 언어로 AI 가 글을 쓰는 일을 막는다.
   */
  public AppLocale resolveContentLocale(AppLocale requested) {
    Set<AppLocale> enabled = current();
    if (enabled.contains(requested)) {
      return requested;
    }
    return enabled.contains(AppLocale.EN) ? AppLocale.EN : AppLocale.KO;
  }

  /** 관대한 읽기. 알 수 없는 코드와 빈 토큰은 건너뛰고, ko 는 늘 넣는다. */
  public static Set<AppLocale> parse(String csv) {
    Set<AppLocale> result = EnumSet.of(AppLocale.KO);
    if (csv != null) {
      for (String token : csv.split(",")) {
        String code = token.trim().toLowerCase(Locale.ROOT);
        if (code.isEmpty()) {
          continue;
        }
        try {
          result.add(AppLocale.fromCode(code));
        } catch (IllegalArgumentException e) {
          log.warn("[EnabledLocales] 알 수 없는 언어 코드는 건너뜁니다: {}", token);
        }
      }
    }
    return Collections.unmodifiableSet(result);
  }

  /**
   * 엄격한 저장 검증. 알 수 없는 코드나 빈 값이면 던지고, 통과하면 ko 를 앞에 붙여 enum 순서로 고정한 CSV 를 준다.
   *
   * @throws CustomException {@link ErrorCode#SYSTEM_CONFIG_INVALID_VALUE}
   */
  public static String normalize(String csv) {
    Set<AppLocale> result = EnumSet.of(AppLocale.KO);
    boolean any = false;
    if (csv != null) {
      for (String token : csv.split(",")) {
        String code = token.trim().toLowerCase(Locale.ROOT);
        if (code.isEmpty()) {
          continue;
        }
        try {
          result.add(AppLocale.fromCode(code));
          any = true;
        } catch (IllegalArgumentException e) {
          throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
        }
      }
    }
    if (!any) {
      throw new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
    }
    return result.stream().map(AppLocale::code).collect(Collectors.joining(","));
  }
}
