package com.chuseok22.elumserver.ai.core;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.function.Supplier;

/**
 * AI 호출 로그에 회원을 연결하기 위한 컨텍스트 홀더.
 * 클라이언트(GeminiTextClient 등)는 호출자가 누구인지 모르므로, 요청 처리 진입점
 * (RoutineService)이 memberId를 담아두면 클라이언트가 로그 기록 시점에 꺼내 쓴다.
 * InheritableThreadLocal을 쓰는 이유 — RoutineAiPipeline이 이미지 생성을 가상 스레드로
 * 병렬 실행하는데, 자식 스레드에도 memberId가 전파돼야 이미지 호출 로그에 회원이 남는다.
 * 일과 콘텐츠 언어도 같은 길로 싣는다(프롬프트 행 선택, 스키마 문구, 이름 치환이 따름).
 * 관리자 테스트 호출처럼 컨텍스트가 없으면 null(회원 미상)로 기록된다.
 */
public final class AiCallContext {

  private static final InheritableThreadLocal<String> MEMBER_ID = new InheritableThreadLocal<>();
  /// 크레딧 작업 id. 작업 하나에 딸린 호출의 실제 USD 를 모아 대조하려고 호출 기록에 단다.
  private static final InheritableThreadLocal<String> CREDIT_JOB_ID = new InheritableThreadLocal<>();
  /// 일과 콘텐츠 언어. 메서드 인자 대신 여기 싣는 이유: 회원·작업 id 가 이미 같은 길로 가고, 시그니처를 바꾸면 목 스텁 테스트가 대거 바뀐다. 비어 있으면 KO.
  private static final InheritableThreadLocal<AppLocale> CONTENT_LOCALE = new InheritableThreadLocal<>();

  private AiCallContext() {
  }

  public static void setMemberId(String memberId) {
    MEMBER_ID.set(memberId);
  }

  public static String currentMemberId() {
    return MEMBER_ID.get();
  }

  public static void setCreditJobId(String creditJobId) {
    CREDIT_JOB_ID.set(creditJobId);
  }

  public static String currentCreditJobId() {
    return CREDIT_JOB_ID.get();
  }

  /// null 을 넣으면 비운다.
  public static void setContentLocale(AppLocale locale) {
    if (locale == null) {
      CONTENT_LOCALE.remove();
    } else {
      CONTENT_LOCALE.set(locale);
    }
  }

  public static AppLocale currentContentLocale() {
    AppLocale locale = CONTENT_LOCALE.get();
    return locale == null ? AppLocale.KO : locale;
  }

  /// 일과 언어를 세우고 action 을 실행한 뒤 반드시 비운다(예외 포함). 헤더가 아닌 일과 언어로 AI 를 부를 때 쓴다.
  public static <T> T callWithContentLocale(AppLocale locale, Supplier<T> action) {
    setContentLocale(locale);
    try {
      return action.get();
    } finally {
      setContentLocale(null);
    }
  }

  public static void runWithContentLocale(AppLocale locale, Runnable action) {
    callWithContentLocale(locale, () -> {
      action.run();
      return null;
    });
  }

  // 요청 스레드는 풀에서 재사용되므로 진입점의 finally에서 반드시 비워야
  // 다음 요청에 이전 회원·작업·언어가 새어 들어가지 않는다. 셋을 함께 비운다.
  public static void clear() {
    MEMBER_ID.remove();
    CREDIT_JOB_ID.remove();
    CONTENT_LOCALE.remove();
  }
}
