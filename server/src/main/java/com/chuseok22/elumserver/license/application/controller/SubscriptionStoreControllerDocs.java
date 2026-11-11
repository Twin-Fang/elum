package com.chuseok22.elumserver.license.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.license.application.dto.request.AppleSubscriptionVerifyRequest;
import com.chuseok22.elumserver.license.application.dto.request.GoogleSubscriptionVerifyRequest;
import com.chuseok22.elumserver.license.application.dto.response.SubscriptionVerifyResponse;
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
  name = "Subscription",
  description = "App Store·Google Play 구독 결제를 서버가 확인해 Pro 를 켜는 API (#1071). 보호자 accessToken(Bearer) 이 필요합니다. "
    + "이룸이 권한으로는 부를 수 없습니다."
)
public interface SubscriptionStoreControllerDocs {

  @Operation(
    summary = "App Store 구독 확인",
    description = """
      StoreKit 2 로 결제하거나 구매를 복원한 뒤 부릅니다. **앱이 보낸 값만 믿지 않습니다** — Apple 서명을 확인하고,
      서버에 App Store Server API 키가 있으면 Apple 에 최신 상태를 다시 묻습니다.

      **앱이 지킬 것**
      - 구매할 때 `appAccountToken` 에 **이 보호자의 회원 id(UUID)** 를 넣습니다. 앱이 서버에 알리기 전에 꺼져도
        Apple 결제 알림만으로 이 계정에 Pro 가 켜집니다.
      - `verification=PENDING` 이면 Pro 가 아직 켜지지 않았습니다. "확인 중"으로 보이고 잠시 뒤 같은 요청을 다시 보냅니다.
      - Transaction.finish() 는 이 응답이 200 일 때 부릅니다.

      **처리 로직**
      1. 기능이 꺼져 있으면 403 `SUBSCRIPTION_STORE_DISABLED`.
      2. 서명·인증서 체인·번들 ID 가 맞지 않으면 400 `SUBSCRIPTION_RECEIPT_INVALID`.
      3. Sandbox(TestFlight) 결제인데 테스트 결제 허용이 꺼져 있으면 400 `SUBSCRIPTION_ENVIRONMENT_NOT_ALLOWED`.
      4. 허용 상품이 아니면 400 `SUBSCRIPTION_PRODUCT_NOT_ALLOWED`.
      5. 이 구독이 **다른 이룸 계정**에 이미 묶여 있으면 400 `SUBSCRIPTION_OWNED_BY_OTHER_MEMBER` (구매 복원을 다른 계정에서 시도).
      6. 같은 거래를 다시 보내면 아무것도 바뀌지 않고 같은 결과를 돌려줍니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "확인 결과 (ACTIVE · INACTIVE · PENDING)",
      content = @Content(schema = @Schema(implementation = SubscriptionVerifyResponse.class))),
    @ApiResponse(responseCode = "400", description = "영수증·환경·상품 거부, 다른 계정의 구독",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "기능 꺼짐 또는 이룸이 권한",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<SubscriptionVerifyResponse> verifyApple(Authentication authentication, AppleSubscriptionVerifyRequest request);

  @Operation(
    summary = "Google Play 구독 확인",
    description = """
      Play Billing 으로 결제하거나 구매를 복원한 뒤 부릅니다. 서버가 Google Play Developer API 로 구독을 직접 조회하고,
      확인되면 구매 확인(acknowledge)까지 합니다. **앱은 acknowledge 를 하지 않습니다.**

      **앱이 지킬 것**
      - 구매할 때 `setObfuscatedAccountId` 에 **이 보호자의 회원 id(UUID)** 를 넣습니다.
      - `verification=PENDING` 이면 Pro 가 아직 켜지지 않았습니다. 잠시 뒤 다시 보냅니다.

      **처리 로직**
      1. 기능이 꺼져 있으면 403 `SUBSCRIPTION_STORE_DISABLED`, 서버에 Google 연결 설정이 없으면 503 `SUBSCRIPTION_STORE_NOT_CONFIGURED`.
      2. 허용 상품이 아니면 400 `SUBSCRIPTION_PRODUCT_NOT_ALLOWED`.
      3. Google 에 없는 토큰·상품 불일치면 400 `SUBSCRIPTION_RECEIPT_INVALID`.
      4. 라이선스 테스터 결제인데 테스트 결제 허용이 꺼져 있으면 400 `SUBSCRIPTION_ENVIRONMENT_NOT_ALLOWED`.
      5. 다른 이룸 계정에 묶인 구독이면 400 `SUBSCRIPTION_OWNED_BY_OTHER_MEMBER`.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "확인 결과 (ACTIVE · INACTIVE · PENDING)",
      content = @Content(schema = @Schema(implementation = SubscriptionVerifyResponse.class))),
    @ApiResponse(responseCode = "400", description = "영수증·환경·상품 거부, 다른 계정의 구독",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "기능 꺼짐 또는 이룸이 권한",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "503", description = "서버에 Google 연결 설정이 없음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<SubscriptionVerifyResponse> verifyGoogle(Authentication authentication, GoogleSubscriptionVerifyRequest request);
}
