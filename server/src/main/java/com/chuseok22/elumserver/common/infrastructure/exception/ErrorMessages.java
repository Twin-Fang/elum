package com.chuseok22.elumserver.common.infrastructure.exception;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import java.util.Locale;
import org.springframework.context.MessageSource;
import org.springframework.context.support.ResourceBundleMessageSource;
import org.springframework.validation.FieldError;

/**
 * 에러 응답 문구를 요청 언어로 고른다.
 *
 * <p>원본은 {@code i18n/messages_{언어}.properties} 이고 키는 {@link ErrorCode} 이름이다. 대체 순서는
 * {@link AppLocale#fallbackChain()} 을 따른다 (ko 는 ko 만, 그 외는 요청 언어 → en → ko).
 * 값이 비었거나 키가 없으면 다음 언어로 넘어가므로, 번역 파일이 비어 있어도 서버는 정상 동작한다.
 *
 * <p>스프링 빈이 아니라 정적으로 둔다 — 필터·인증 진입점·예외 어드바이스가 모두 직접 {@code new} 로 만들어지는 곳이라
 * 주입을 끌어오면 기존 생성자가 줄줄이 바뀐다.
 */
public final class ErrorMessages {

  private static final String BASENAME = "i18n/messages";
  private static final ErrorMessages DEFAULT = new ErrorMessages(standardSource());
  // 테스트가 가짜 문구를 끼울 수 있게 비final 로 둔다. 운영 코드는 바꾸지 않는다.
  private static volatile ErrorMessages standard = DEFAULT;

  private final MessageSource source;

  public ErrorMessages(MessageSource source) {
    this.source = source;
  }

  public static ErrorMessages standard() {
    return standard;
  }

  /** 테스트 전용: standard() 를 가짜로 바꾼다. 반드시 {@link #resetStandardForTesting()} 으로 되돌린다. */
  public static void overrideStandardForTesting(ErrorMessages replacement) {
    standard = replacement;
  }

  public static void resetStandardForTesting() {
    standard = DEFAULT;
  }

  private static MessageSource standardSource() {
    ResourceBundleMessageSource bundle = new ResourceBundleMessageSource();
    bundle.setBasename(BASENAME);
    bundle.setDefaultEncoding("UTF-8");
    // 서버 JVM 의 기본 언어로 새지 않게 한다. 대체 순서는 이 클래스가 직접 정한다.
    bundle.setFallbackToSystemLocale(false);
    return bundle;
  }

  /** 지금 요청의 언어로 고른 문구. */
  public String of(ErrorCode code) {
    return of(code, CurrentLocale.get());
  }

  public String of(ErrorCode code, AppLocale locale) {
    return of(code.name(), locale, code.name());
  }

  /**
   * @param defaultText 어느 언어에도 키가 없을 때 돌려줄 문구(예: DTO 에 적은 한국어 message)
   */
  public String of(String key, AppLocale locale, String defaultText) {
    // ko 요청은 영어로 새지 않는다 — fallbackChain() 이 KO 에서 [KO] 만 준다.
    for (AppLocale candidate : locale.fallbackChain()) {
      String message = source.getMessage(key, null, null, Locale.of(candidate.code()));
      if (message != null && !message.isBlank()) {
        return message;
      }
    }
    return defaultText;
  }

  /**
   * 요청 검증 실패 필드 하나의 문구. 키는 {@code validation.{객체이름}.{필드}.{제약}} 이다.
   * 어느 언어에도 키가 없으면 DTO 에 적은 message(한국어)를 그대로 준다 — 헤더 없는 앱의 응답이 바뀌지 않는다.
   */
  public String ofValidation(FieldError error, AppLocale locale) {
    String key = "validation." + error.getObjectName() + "." + error.getField() + "." + error.getCode();
    return of(key, locale, error.getDefaultMessage());
  }
}
