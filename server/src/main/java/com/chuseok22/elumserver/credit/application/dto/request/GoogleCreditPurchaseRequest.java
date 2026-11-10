package com.chuseok22.elumserver.credit.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "Google Play 크레딧 꾸러미 구매 확인 요청 (Play Billing 소모성 상품)")
public record GoogleCreditPurchaseRequest(

  @Schema(description = "꾸러미 상품 ID (꾸러미 목록의 productId)", example = "elum_credit_150",
    requiredMode = Schema.RequiredMode.REQUIRED)
  String productId,

  @Schema(description = "Purchase.getPurchaseToken()", requiredMode = Schema.RequiredMode.REQUIRED)
  String purchaseToken
) {

}
