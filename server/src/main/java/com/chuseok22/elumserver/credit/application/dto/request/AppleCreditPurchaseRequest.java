package com.chuseok22.elumserver.credit.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "App Store 크레딧 꾸러미 구매 확인 요청 (StoreKit 2 소모성 상품)")
public record AppleCreditPurchaseRequest(

  @Schema(description = "Transaction.jwsRepresentation (서명된 거래 JWS)", requiredMode = Schema.RequiredMode.REQUIRED)
  String signedTransaction
) {

}
