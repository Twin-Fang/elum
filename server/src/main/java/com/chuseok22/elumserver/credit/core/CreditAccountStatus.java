package com.chuseok22.elumserver.credit.core;

/** 크레딧 계정 상태 (#407). FROZEN 이면 잔액과 상관없이 새 예약을 막는다. */
public enum CreditAccountStatus {
  ACTIVE,
  FROZEN,
}
