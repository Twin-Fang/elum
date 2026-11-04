package com.chuseok22.elumserver.license.core;

/**
 * 스토어 구독 상태를 바꾼 계기 2개: 앱 검증 요청, 스토어 결제 알림
 */
public enum StorePurchaseTrigger {
  CLIENT_VERIFY,
  STORE_NOTIFICATION,
}
