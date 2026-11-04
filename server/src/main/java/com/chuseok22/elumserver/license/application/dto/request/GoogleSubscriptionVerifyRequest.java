package com.chuseok22.elumserver.license.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "Google Play 구독 검증 요청 (Play Billing)")
public record GoogleSubscriptionVerifyRequest(

  @Schema(description = "Purchase.getPurchaseToken()", requiredMode = Schema.RequiredMode.REQUIRED)
  String purchaseToken,

  @Schema(description = "구독 상품 ID (Play Console 의 구독 ID)", example = "elum_pro_monthly",
    requiredMode = Schema.RequiredMode.REQUIRED)
  String productId
) {

}
