package com.chuseok22.elumserver.license.application.service;

/**
 * 구매한 크레딧이 남아 있는가: Free 회원도 구매분이 있는 동안 AI 그림을 쓰게 하는 판정의 근거
 * 크레딧 도메인이 구현한다 (license 가 크레딧 저장소를 직접 알지 않게)
 */
public interface PurchasedCreditChecker {

  /// 지금 쓸 수 있는 구매 묶음의 남은 양이 0 보다 큰가. 조회 실패는 false
  boolean hasUsablePurchasedCredit(String memberId);
}
