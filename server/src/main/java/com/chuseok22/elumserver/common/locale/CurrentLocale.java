package com.chuseok22.elumserver.common.locale;

import java.util.function.Supplier;

/**
 * 지금 처리 중인 요청의 언어 (다국어 #526).
 *
 * <p>{@link AcceptLanguageFilter} 가 요청 앞에서 심고 뒤에서 비운다. 요청 밖(스케줄러·기동·테스트)은 KO 다.
 * {@code AiCallContext} 와 같은 이유로 InheritableThreadLocal 을 쓴다 — 이미지 생성이 가상 스레드로 병렬 실행되어도
 * 요청 언어가 따라간다. 풀의 스레드는 필터가 매번 비운다.
 */
public final class CurrentLocale {

  private static final InheritableThreadLocal<AppLocale> CURRENT = new InheritableThreadLocal<>();

  private CurrentLocale() {
  }

  /** 요청 안이면 헤더가 정한 언어, 밖이면 KO. */
  public static AppLocale get() {
    AppLocale locale = CURRENT.get();
    return locale == null ? AppLocale.KO : locale;
  }

  /** 요청이 아닌 곳(테스트 등)에서 잠시 언어를 정한다. 끝나면 이전 값으로 되돌린다. */
  public static <T> T callAs(AppLocale locale, Supplier<T> body) {
    AppLocale previous = CURRENT.get();
    CURRENT.set(locale);
    try {
      return body.get();
    } finally {
      if (previous == null) {
        CURRENT.remove();
      } else {
        CURRENT.set(previous);
      }
    }
  }

  public static void runAs(AppLocale locale, Runnable body) {
    callAs(locale, () -> {
      body.run();
      return null;
    });
  }

  static void set(AppLocale locale) {
    CURRENT.set(locale);
  }

  static void clear() {
    CURRENT.remove();
  }
}
