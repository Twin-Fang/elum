package com.chuseok22.elumserver.credit.application.dto.response;

import com.chuseok22.elumserver.credit.core.CreditPurchaseResultStatus;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "크레딧 구매 확인 결과")
public record CreditPurchaseResponse(
  @Schema(description = "GRANTED 이번에 적립 | ALREADY_GRANTED 이미 적립된 거래 | PENDING 결제 보류·스토어 확인 지연(적립 안 함, 나중에 다시 확인)",
    example = "GRANTED")
  CreditPurchaseResultStatus status,
  @Schema(description = "이 거래로 적립한 크레딧 (PENDING 이면 0)", example = "150")
  int grantedCredits,
  @Schema(description = "확인 뒤 지금 쓸 수 있는 크레딧", example = "184")
  int available
) {

  /// 적립하지 않고 나중에 다시 확인하는 경우
  public static CreditPurchaseResponse pending(int available) {
    return new CreditPurchaseResponse(CreditPurchaseResultStatus.PENDING, 0, available);
  }
}
