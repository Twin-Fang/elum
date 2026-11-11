package com.chuseok22.elumserver.license.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "App Store 구독 검증 요청 (StoreKit 2)")
public record AppleSubscriptionVerifyRequest(

  @Schema(description = "Transaction.jwsRepresentation (서명된 거래 JWS)", requiredMode = Schema.RequiredMode.REQUIRED)
  String signedTransaction,

  @Schema(description = "Product.SubscriptionInfo.RenewalInfo 의 jwsRepresentation. 있으면 자동 갱신·결제 유예를 바로 알 수 있다 (선택)")
  String signedRenewalInfo
) {

}
