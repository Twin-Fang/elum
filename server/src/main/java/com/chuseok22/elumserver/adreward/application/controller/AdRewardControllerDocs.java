package com.chuseok22.elumserver.adreward.application.controller;

import com.chuseok22.elumserver.adreward.application.dto.response.AdRewardOfferResponse;
import com.chuseok22.elumserver.adreward.application.dto.response.AdRewardSessionResponse;
import com.chuseok22.elumserver.adreward.application.dto.response.AdRewardSessionStatusResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
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
  name = "AdReward",
  description = "보상형 광고를 보고 AI 생성 크레딧을 받는 API (#463). 보호자 accessToken(Bearer) 인증이 필요합니다. "
    + "이룸이 권한으로는 부를 수 없습니다."
)
public interface AdRewardControllerDocs {

  @Operation(
    summary = "광고 보고 더 만들기 제안",
    description = """
      앱이 크레딧을 다 썼을 때 **"광고 보고 더 만들기"를 보일지** 정하는 값을 돌려줍니다. 아무것도 쓰지 않습니다.

      `enabled=false`면 버튼을 보이지 않습니다. 기능이 꺼져 있거나, 오늘 받을 수 있는 횟수를 다 썼거나,
      계정이 멈춰 있을 때입니다. 이유는 알려 주지 않습니다(앱은 그냥 숨깁니다).
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공",
      content = @Content(schema = @Schema(implementation = AdRewardOfferResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<AdRewardOfferResponse> offer(Authentication authentication);

  @Operation(
    summary = "광고 보상 세션 만들기",
    description = """
      광고를 요청하기 **전에** 부릅니다. 돌려준 `nonce`를 광고 요청의 `ServerSideVerificationOptions.customData`에 실으면
      Google 이 시청이 끝났을 때 서버로 콜백을 보내고, 서버가 서명을 확인한 뒤 크레딧을 줍니다. **앱이 "봤다"고 알리는
      요청은 없습니다.**

      **처리 로직**
      1. 기능이 꺼져 있으면 403 `AD_REWARD_DISABLED`.
      2. 계정이 멈춰 있으면 403 `AD_REWARD_ACCOUNT_FROZEN`.
      3. 오늘(한국 시각 0시 시작) 받은 횟수가 상한이면 403 `AD_REWARD_DAILY_LIMIT`.
      4. 기다리는 세션이 있으면 **그것을 다시 돌려줍니다**(새로 만들지 않습니다). 없으면 새 세션을 만듭니다.

      광고를 다 본 뒤에는 `GET /sessions/{nonce}`로 상태를 확인합니다. 지급이 끝나기 전에 같은 회원이 새 광고를 시작하지
      않도록 앱이 막아야 합니다(한 세션은 한 번만 지급됩니다).
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "세션 발급",
      content = @Content(schema = @Schema(implementation = AdRewardSessionResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403",
      description = "꺼짐(AD_REWARD_DISABLED) · 멈춘 계정(AD_REWARD_ACCOUNT_FROZEN) · 오늘 상한(AD_REWARD_DAILY_LIMIT)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "503", description = "크레딧 장부를 읽지 못함(AD_CREDIT_UNAVAILABLE 계열)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<AdRewardSessionResponse> createSession(Authentication authentication);

  @Operation(
    summary = "광고 보상 세션 상태 조회",
    description = """
      광고를 다 본 뒤 폴링합니다. 지급은 Google 콜백이 서버에 닿은 뒤에 일어나므로 몇 초 걸릴 수 있습니다.

      | status | 뜻 |
      |---|---|
      | `PENDING` | 콜백을 기다리는 중 (계속 폴링) |
      | `GRANTED` | 지급됨. `grantedCredits` 만큼 늘었습니다 |
      | `REJECTED` | 콜백은 맞았지만 주지 않음. `reason` 참고 |
      | `EXPIRED` | 유효 시간 안에 콜백이 오지 않음 |

      **내 세션만 볼 수 있습니다.** 남의 세션이나 없는 세션은 똑같이 404 `AD_REWARD_SESSION_NOT_FOUND` 입니다.
      """
  )
  @SecurityRequirement(name = "bearerAuth")
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공",
      content = @Content(schema = @Schema(implementation = AdRewardSessionStatusResponse.class))),
    @ApiResponse(responseCode = "401", description = "accessToken이 없거나 유효하지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "404", description = "세션이 없거나 내 것이 아님(AD_REWARD_SESSION_NOT_FOUND)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<AdRewardSessionStatusResponse> getSessionStatus(Authentication authentication, String nonce);
}
