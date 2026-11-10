package com.chuseok22.elumserver.credit.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.credit.application.dto.request.AppleCreditPurchaseRequest;
import com.chuseok22.elumserver.credit.application.dto.request.GoogleCreditPurchaseRequest;
import com.chuseok22.elumserver.credit.application.dto.response.CreditPacksResponse;
import com.chuseok22.elumserver.credit.application.dto.response.CreditPurchaseResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

@Tag(
  name = "Credit Purchase",
  description = "추가 크레딧 구매(소모성 상품) API. 보호자 accessToken(Bearer) 인증이 필요합니다."
)
public interface CreditPurchaseControllerDocs {

  @Operation(
    summary = "크레딧 꾸러미 목록",
    description = """
      판매 중인 꾸러미(상품 ID·개수)를 돌려줍니다. **가격은 서버가 모릅니다** — 앱이 스토어에서 상품 ID로 읽습니다.

      판매 스위치(`CREDIT_PACK_SALE_ENABLED`)가 꺼져 있으면 `isSaleEnabled=false` 와 빈 `packs` 입니다.
      `isPopular` 는 설정 `CREDIT_PACK_POPULAR_PRODUCT_ID` 와 같은 상품에만 true 입니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공",
      content = @Content(schema = @Schema(implementation = CreditPacksResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<CreditPacksResponse> getPacks();

  @Operation(
    summary = "App Store 크레딧 구매 확인 · 적립",
    description = """
      StoreKit 2 소모성 상품 거래(JWS)를 검증하고 크레딧을 적립합니다.

      **처리 로직**: 판매 켜짐 확인 → 서명·번들·환경 검증(구독과 같은 규칙) → 소모성 거래·취소 안 됨 확인 →
      상품 ID 가 꾸러미 목록에 있는지 확인 → 거래 id(transactionId)로 한 번만 적립.

      **status**: `GRANTED` 이번에 적립 · `ALREADY_GRANTED` 같은 거래가 다시 옴(재시도·복원) · `PENDING` 적립하지 않음.
      같은 거래를 두 번 보내도 한 번만 적립됩니다. 적립분은 만료가 없고 가장 나중에 쓰입니다.

      **오류**: 403 `CREDIT_PACK_SALE_DISABLED`(판매 꺼짐) · `SUBSCRIPTION_STORE_DISABLED` ·
      400 `SUBSCRIPTION_RECEIPT_INVALID`(서명·소모성 아님·취소됨) · `SUBSCRIPTION_ENVIRONMENT_NOT_ALLOWED` ·
      `SUBSCRIPTION_PRODUCT_NOT_ALLOWED`(꾸러미에 없는 상품) · `CREDIT_PURCHASE_OWNED_BY_OTHER_MEMBER`(다른 계정에 적립된 거래)
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "확인 성공",
      content = @Content(schema = @Schema(implementation = CreditPurchaseResponse.class))),
    @ApiResponse(responseCode = "400", description = "영수증·상품·환경·다른 계정 거래 오류",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "판매 또는 스토어 연동이 꺼져 있음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<CreditPurchaseResponse> purchaseApple(Authentication authentication, AppleCreditPurchaseRequest request);

  @Operation(
    summary = "Google Play 크레딧 구매 확인 · 적립",
    description = """
      Play Billing 소모성 상품 구매를 조회·검증하고 크레딧을 적립합니다.

      **처리 로직**: 판매 켜짐 확인 → 상품 ID 가 꾸러미 목록에 있는지 확인 → Google 에 상품 구매 조회 →
      결제 완료(보류·취소 제외)·테스트 결제 허용 확인 → 주문 id(orderId)로 한 번만 적립 → 소비(consume).
      소비가 실패해도 적립은 유지되고 같은 요청을 다시 보내면 소비를 다시 시도합니다.

      **status**: Apple 과 같습니다. 결제가 보류 중이거나 Google 확인이 늦으면 `PENDING`(적립 안 함, 나중에 다시 확인).
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "확인 성공",
      content = @Content(schema = @Schema(implementation = CreditPurchaseResponse.class))),
    @ApiResponse(responseCode = "400", description = "구매·상품·환경·다른 계정 거래 오류",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "판매 또는 스토어 연동이 꺼져 있음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "503", description = "스토어 연결 설정이 없음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<CreditPurchaseResponse> purchaseGoogle(Authentication authentication, GoogleCreditPurchaseRequest request);
}
