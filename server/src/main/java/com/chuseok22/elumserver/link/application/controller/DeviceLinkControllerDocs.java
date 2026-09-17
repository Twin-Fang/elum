package com.chuseok22.elumserver.link.application.controller;

import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.link.application.dto.request.RedeemLinkRequest;
import com.chuseok22.elumserver.link.application.dto.response.LinkCodeResponse;
import com.chuseok22.elumserver.link.application.dto.response.LinkStatusResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

@Tag(
  name = "DeviceLink",
  description = "이룸이 휴대폰 연결 API. 보호자가 여섯 글자 연결 암호를 발급해 불러주면 "
    + "이룸이 휴대폰이 그것을 넣어 같은 계정에 붙습니다. QR은 쓰지 않습니다."
)
public interface DeviceLinkControllerDocs {

  @Operation(
    summary = "연결 암호 발급 (보호자)",
    description = "여섯 글자 연결 암호를 만듭니다. 10분 동안 한 번만 쓸 수 있습니다.\n\n"
      + "- 헷갈리는 글자(`0 O 1 I L U`)는 만들지 않습니다 — 불러주고 받아적기 때문입니다.\n"
      + "- **이전에 발급한 미사용 암호는 폐기됩니다.** 화면에 보이는 암호만 통해야 합니다.\n"
      + "- 이미 연결된 이룸이 휴대폰은 그대로 둡니다. 연결을 끊으려면 `DELETE /current`를 씁니다.\n"
      + "- 응답의 `code`가 원문이 나가는 유일한 자리입니다. 서버에는 해시만 남습니다.",
    security = @SecurityRequirement(name = "bearerAuth")
  )
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "발급 성공"),
    @ApiResponse(responseCode = "401", description = "인증 실패",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "이룸이 휴대폰에서는 발급할 수 없음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<LinkCodeResponse> issue(Authentication authentication);

  @Operation(
    summary = "연결 상태 조회 (보호자)",
    description = "설정 화면이 쓰는 값입니다.\n\n"
      + "- `NONE` — 연결도 발급도 없음 → `이룸이 휴대폰 연결하기`\n"
      + "- `PENDING` — 암호를 발급했고 아직 아무도 안 씀 (`expiresAt` 참고)\n"
      + "- `LINKED` — 연결됨 (`linkedAt`으로 `9월 18일부터`를 만든다)",
    security = @SecurityRequirement(name = "bearerAuth")
  )
  @ApiResponse(responseCode = "200", description = "조회 성공")
  ResponseEntity<LinkStatusResponse> status(Authentication authentication);

  @Operation(
    summary = "연결 끊기 (보호자)",
    description = "연결된 이룸이 휴대폰을 끊습니다. **그 기기의 세션만** 폐기하므로 "
      + "보호자 로그인은 유지됩니다.\n\n"
      + "이룸이 휴대폰을 잃어버렸거나 기기를 바꿨거나 남의 폰에 잘못 연결했을 때 "
      + "보호자가 끊을 수 있는 유일한 길입니다.",
    security = @SecurityRequirement(name = "bearerAuth")
  )
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "끊음"),
    @ApiResponse(responseCode = "404", description = "연결된 휴대폰이 없음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<Void> revoke(Authentication authentication);

  @Operation(
    summary = "연결 암호 넣기 (이룸이 휴대폰) — 인증 불필요",
    description = "받은 여섯 글자를 넣어 계정에 붙습니다. 성공하면 **이룸이용 토큰**을 받습니다 "
      + "(일과 조회·완료 표시만 가능).\n\n"
      + "- 소문자로 보내도 되고 사이 공백이 있어도 됩니다 (`a7k 3m9` → `A7K3M9`).\n"
      + "- 한 암호에 5회 틀리면 그 암호는 폐기됩니다.\n"
      + "- 호출자당 분당 10회를 넘으면 429를 돌려줍니다.\n"
      + "- 없는 암호와 이미 쓴 암호는 **같은 응답**입니다 — 존재 여부를 흘리지 않습니다."
  )
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "연결 성공 (토큰 발급)"),
    @ApiResponse(responseCode = "404", description = "암호가 맞지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "410", description = "암호 만료",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "429", description = "시도가 너무 잦음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<TokenResponse> redeem(RedeemLinkRequest request, HttpServletRequest http);
}
