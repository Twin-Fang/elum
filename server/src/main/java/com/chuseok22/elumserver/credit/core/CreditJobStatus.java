package com.chuseok22.elumserver.credit.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 생성 작업의 상태.
 *
 * <pre>
 *   RESERVED ──┬── 저장 성공 ──▶ SETTLED  (청구 확정)
 *              ├── 실패 ───────▶ RELEASED (예약 반환)
 *              └── TTL 초과 ────▶ EXPIRED  (멈춘 예약 자동 반환)
 * </pre>
 * label 은 관리자 화면 표시 이름
 */
@Getter
@AllArgsConstructor
public enum CreditJobStatus {
  RESERVED("예약 중"),
  SETTLED("정산"),
  RELEASED("반환"),
  EXPIRED("만료 반환"),
  ;

  private final String label;
}
