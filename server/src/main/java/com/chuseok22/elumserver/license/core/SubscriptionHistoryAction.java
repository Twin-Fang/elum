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
  ;

  private final String label;
}
