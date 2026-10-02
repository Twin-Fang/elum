package com.chuseok22.elumserver.common.infrastructure.exception;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import java.util.Locale;
import org.springframework.context.MessageSource;
import org.springframework.context.support.ResourceBundleMessageSource;

/**
 * 에러 응답 문구를 요청 언어로 고른다 (다국어 #526).
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
  private static final ErrorMessages STANDARD = new ErrorMessages(standardSource());

  private final MessageSource source;

  public ErrorMessages(MessageSource source) {
    this.source = source;
  }

  public static ErrorMessages standard() {
    return STANDARD;
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
}
