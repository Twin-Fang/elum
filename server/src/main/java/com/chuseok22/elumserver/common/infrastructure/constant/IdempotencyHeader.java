package com.chuseok22.elumserver.common.infrastructure.constant;

/**
 * 요청 멱등 키 헤더 (일과 만들기·다른 언어로 만들기): 같은 키로 다시 오면 AI 를 다시 부르지 않고 만든 결과를 돌려줌
 * 앱 짝: client/lib/core/network/idempotency_key.dart `idempotencyKeyHeader` (CrossStackContractTest 가 대조)
 */
public final class IdempotencyHeader {

  public static final String NAME = "Idempotency-Key";

  private IdempotencyHeader() {
  }
}
