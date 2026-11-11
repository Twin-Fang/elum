package com.chuseok22.elumserver.license.application.service.store;

/**
 * 앱 검증 요청 결과 3개: Pro 이용 중, 확인됐지만 Pro 아님(만료·환불·결제 대기), 스토어 확인 중(잠시 뒤 다시)
 */
public enum StoreVerification {
  ACTIVE,
  INACTIVE,
  PENDING,
}
