package com.chuseok22.elumserver.common.locale;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;

/**
 * 서버가 다루는 언어 다섯.
 *
 * <p>내부 코드는 소문자 두 글자다. HTTP {@code Accept-Language} 로는 {@code zh-Hans} 가 오지만 서버는 {@code zh} 로 본다.
 */
public enum AppLocale {
  KO("ko"), EN("en"), JA("ja"), ZH("zh"), ES("es");

  private final String code;

  AppLocale(String code) {
    this.code = code;
  }

  public String code() {
    return code;
  }

  /**
   * 대체 순서: 요청 언어 → en → ko. 겹치는 언어는 처음 나온 자리만 남긴다.
   *
   * <p>KO 는 {@code [KO]} 만 돌려준다. ko 문구가 비었을 때 한국어 사용자에게 영어가 새면 안 되기 때문이다(C2).
   */
  public List<AppLocale> fallbackChain() {
    if (this == KO) {
      return List.of(KO);
    }
    LinkedHashSet<AppLocale> chain = new LinkedHashSet<>();
    chain.add(this);
    chain.add(EN);
    chain.add(KO);
    return List.copyOf(chain);
  }

  /** 정확히 일치하는 코드만 받는다. 저장된 값을 읽을 때 쓰므로 모르는 값은 조용히 넘기지 않는다. */
  public static AppLocale fromCode(String code) {
    for (AppLocale locale : values()) {
      if (locale.code.equals(code)) {
        return locale;
      }
    }
    throw new IllegalArgumentException("지원하지 않는 언어 코드: " + code);
  }

  /**
   * {@code Accept-Language} 값을 언어로 바꾼다. 어떤 값이 와도 던지지 않는다.
   *
   * <ul>
   *   <li>헤더가 없거나 비었다 → KO (이미 배포된 앱은 헤더를 보내지 않는다)</li>
   *   <li>첫 번째 태그의 기본 언어만 본다. 품질값(q)은 순서를 바꾸지 않는다 — 앱은 태그 하나만 보낸다</li>
   *   <li>5개 밖이거나 깨졌다 → EN</li>
   * </ul>
   */
  public static AppLocale fromAcceptLanguage(String header) {
    if (header == null || header.isBlank()) {
      return KO;
    }
    String first = null;
    for (String part : header.split(",")) {
      if (!part.isBlank()) {
        first = part;
        break;
      }
    }
    if (first == null) {
      return EN;
    }
    String tag = first.split(";", 2)[0].trim().toLowerCase(Locale.ROOT);
    int cut = indexOfSubtagSeparator(tag);
    String language = cut < 0 ? tag : tag.substring(0, cut);
    for (AppLocale locale : values()) {
      if (locale.code.equals(language)) {
        return locale;
      }
    }
    return EN;
  }

  private static int indexOfSubtagSeparator(String tag) {
    for (int i = 0; i < tag.length(); i++) {
      char c = tag.charAt(i);
      if (c == '-' || c == '_') {
        return i;
      }
    }
    return -1;
  }
}
