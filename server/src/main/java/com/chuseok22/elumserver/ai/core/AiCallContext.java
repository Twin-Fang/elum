package com.chuseok22.elumserver.ai.core;

/**
 * AI 호출 로그에 회원을 연결하기 위한 컨텍스트 홀더.
 * 클라이언트(GeminiTextClient 등)는 호출자가 누구인지 모르므로, 요청 처리 진입점
 * (RoutineService)이 memberId를 담아두면 클라이언트가 로그 기록 시점에 꺼내 쓴다.
 * InheritableThreadLocal을 쓰는 이유 — RoutineAiPipeline이 이미지 생성을 가상 스레드로
 * 병렬 실행하는데, 자식 스레드에도 memberId가 전파돼야 이미지 호출 로그에 회원이 남는다.
 * 관리자 테스트 호출처럼 컨텍스트가 없으면 null(회원 미상)로 기록된다.
 */
public final class AiCallContext {

  private static final InheritableThreadLocal<String> MEMBER_ID = new InheritableThreadLocal<>();
  /// 크레딧 작업 id (#407). 작업 하나에 딸린 호출의 실제 USD 를 모아 대조하려고 호출 기록에 단다.
  private static final InheritableThreadLocal<String> CREDIT_JOB_ID = new InheritableThreadLocal<>();

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

  // 요청 스레드는 풀에서 재사용되므로 진입점의 finally에서 반드시 비워야
  // 다음 요청에 이전 회원·작업이 새어 들어가지 않는다. 둘을 함께 비운다.
  public static void clear() {
    MEMBER_ID.remove();
    CREDIT_JOB_ID.remove();
  }
}
