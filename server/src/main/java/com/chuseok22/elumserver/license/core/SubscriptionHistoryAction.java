package com.chuseok22.elumserver.license.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 요금제 이력의 변경 종류
 */
@Getter
@AllArgsConstructor
public enum SubscriptionHistoryAction {

  GRANT("부여"),
  REVOKE("회수"),
  /// 스토어 결제로 Pro 시작·갱신 (만료일 변경 포함)
  STORE_SYNC("스토어 결제"),
  /// 스토어 구독 만료·환불로 Free
  STORE_END("스토어 구독 종료"),
  ;

  private final String label;
}
