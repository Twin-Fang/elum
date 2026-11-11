package com.chuseok22.elumserver.credit.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.util.List;

@Schema(description = "크레딧 꾸러미 목록. 가격은 앱이 스토어에서 읽는다(서버는 상품 ID와 개수만)")
public record CreditPacksResponse(
  @Schema(description = "판매 중인가. false 면 packs 는 비어 있고 앱은 꾸러미 자리를 숨긴다", example = "true")
  boolean isSaleEnabled,
  @Schema(description = "꾸러미 (설정 순서)")
  List<Pack> packs
) {

  @Schema(description = "꾸러미 하나")
  public record Pack(
    @Schema(description = "스토어 상품 ID (App Store·Google Play 가 같은 ID)", example = "elum_credit_150") String productId,
    @Schema(description = "적립 크레딧 개수", example = "150") int credits,
    @Schema(description = "'인기!' 표시를 붙일 꾸러미인가", example = "true") boolean isPopular
  ) {

  }

  public static CreditPacksResponse saleOff() {
    return new CreditPacksResponse(false, List.of());
  }
}
