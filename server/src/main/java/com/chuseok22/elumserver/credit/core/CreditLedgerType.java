package com.chuseok22.elumserver.credit.core;

/**
 * 원장 한 줄의 종류 (#407). delta 는 "사용 가능량"의 변화라 계정 원장의 누적합이 사용 가능량이 된다.
 *
 * <p>정산은 예약을 먼저 되돌리고(RELEASE +예약) 실제 차감(CONSUME −)을 남긴다 — 예약과 차감을 한 줄로
 * 섞으면 "이번 주 사용량"(CONSUME 합)이 예약량만큼 어긋난다.
 */
public enum CreditLedgerType {
  GRANT,
  RESERVE,
  CONSUME,
  RELEASE,
  EXPIRE,
  ADJUST,
  /// 잔액이 모자라 차감하지 못한 몫. delta 는 0 이고 수량은 reason 에 남긴다.
  OVERAGE,
}
