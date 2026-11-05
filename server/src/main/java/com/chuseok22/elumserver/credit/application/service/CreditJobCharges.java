package com.chuseok22.elumserver.credit.application.service;

import com.chuseok22.elumserver.credit.core.CreditAction;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;

/**
 * 작업 종류 > 예약 행동(원장 action) · 시작 때 단가로 계산한 청구
 */
final class CreditJobCharges {

  private CreditJobCharges() {
  }

  /// 예약량·원장 action 을 정하는 행동. 일과 생성은 글 단가만 예약한다(그림 수는 끝나야 안다). 번역은 글 단가 그대로
  static CreditAction reserveAction(CreditJobKind kind) {
    return switch (kind) {
      case ROUTINE_CREATE, ROUTINE_TRANSLATE -> CreditAction.ROUTINE_TEXT;
      case CARD_IMAGE -> CreditAction.CARD_IMAGE;
      case IMAGE_REGENERATE -> CreditAction.IMAGE_REGENERATE;
    };
  }

  /// 시작 때 단가로 청구를 계산한다.
  static int chargeOf(AiCreditJob job, int imageCount) {
    String costs = job.getCostSnapshot();
    int images = Math.max(0, imageCount);
    return switch (job.getKind()) {
      case ROUTINE_CREATE -> AiCreditPolicy.costFrom(costs, CreditAction.ROUTINE_TEXT)
        + AiCreditPolicy.costFrom(costs, CreditAction.CARD_IMAGE) * images;
      case CARD_IMAGE -> AiCreditPolicy.costFrom(costs, CreditAction.CARD_IMAGE) * images;
      case IMAGE_REGENERATE -> AiCreditPolicy.costFrom(costs, CreditAction.IMAGE_REGENERATE) * images;
      // 그림 수와 무관 (그림을 새로 만들지 않음)
      case ROUTINE_TRANSLATE -> AiCreditPolicy.costFrom(costs, CreditAction.ROUTINE_TEXT);
    };
  }
}
