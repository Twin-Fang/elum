package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.credit.core.CreditPurchaseStatus;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPurchase;

/**
 * 관리자 크레딧 구매 목록 한 줄: 구매 기록 + 회원 표시 이름(없는·탈퇴 회원이면 null)
 */
public record AdminCreditPurchaseRow(AiCreditPurchase purchase, String memberDisplayName) {

  /// 건별 수동 회수 버튼을 보일지 (환불 전만)
  public boolean isRevocable() {
    return purchase.getStatus() == CreditPurchaseStatus.GRANTED;
  }
}
