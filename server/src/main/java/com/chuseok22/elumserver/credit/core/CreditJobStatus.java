package com.chuseok22.elumserver.credit.core;

/**
 * 생성 작업의 상태 (#407).
 *
 * <pre>
 *   RESERVED ──┬── 저장 성공 ──▶ SETTLED  (청구 확정)
 *              ├── 실패 ───────▶ RELEASED (예약 반환)
 *              └── TTL 초과 ────▶ EXPIRED  (멈춘 예약 자동 반환)
 * </pre>
 */
public enum CreditJobStatus {
  RESERVED,
  SETTLED,
  RELEASED,
  EXPIRED,
}
