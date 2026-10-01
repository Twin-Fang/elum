package com.chuseok22.elumserver.member.application.controller;

import com.chuseok22.elumserver.common.infrastructure.exception.ErrorResponse;
import com.chuseok22.elumserver.member.application.dto.request.GuardianUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.RedeemProfileInviteRequest;
import com.chuseok22.elumserver.member.application.dto.response.GuardianListResponse;
import com.chuseok22.elumserver.member.application.dto.response.GuardianResponse;
import com.chuseok22.elumserver.member.application.dto.response.ProfileInviteResponse;
import com.chuseok22.elumserver.member.application.dto.response.ProfileJoinResponse;
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
  name = "ProfileGuardian",
  description = "이룸이를 함께 돌보는 보호자 API (다중 보호자 2단계). 연결된 보호자가 여섯 글자 초대 코드를 발급해 불러주면 "
    + "다른 보호자가 그것을 넣어 같은 이룸이에 붙습니다. 연결된 보호자는 모두 동등하며 윗사람이 없습니다. "
    + "**이룸이 휴대폰은 이 API 를 하나도 쓸 수 없습니다(403).** 연결 암호(이룸이 휴대폰을 붙이는 6자리)와는 다른 것입니다."
)
public interface ProfileGuardianControllerDocs {

  @Operation(
    summary = "초대 코드 발급 (연결된 보호자)",
    description = "다른 보호자를 이 이룸이에 부르는 여섯 글자 코드를 만듭니다. 10분 동안 한 번만 쓸 수 있습니다.\n\n"
      + "- 헷갈리는 글자(`0 O 1 I L U`)는 만들지 않습니다 — 불러주고 받아적기 때문입니다.\n"
      + "- **내가 이 이룸이에 낸 이전 미사용 코드는 폐기됩니다.** 화면에 보이는 코드만 통해야 합니다. 다른 사람이 낸 코드는 그대로입니다.\n"
      + "- 응답의 `code`가 원문이 나가는 유일한 자리입니다. 서버에는 해시만 남습니다.\n"
      + "- 내가 이 이룸이에서 나가면 내가 낸 미사용 코드는 폐기됩니다.\n"
      + "- 계정당 10분에 10번까지 발급할 수 있습니다.",
    security = @SecurityRequirement(name = "bearerAuth")
  )
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "발급 성공"),
    @ApiResponse(responseCode = "403", description = "이룸이 휴대폰이거나(DEVICE_LINK_FORBIDDEN_FOR_ELUMI) 이 이룸이에 연결돼 있지 않음(PROFILE_ACCESS_DENIED). 없는 이룸이도 같은 응답",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "429", description = "너무 잦음 (PROFILE_INVITE_TOO_MANY_ATTEMPTS)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<ProfileInviteResponse> issueInvite(Authentication authentication, String profileId);

  @Operation(
    summary = "초대 코드 넣기 — 이룸이에 합류 (로그인한 보호자)",
    description = "받은 여섯 글자를 넣어 그 이룸이를 함께 돌보는 사람이 됩니다. `kind` 는 `GUARDIAN` 으로 붙고, "
      + "복지사 표시는 붙은 뒤 `PATCH /api/profiles/{profileId}/guardians/me` 로 바꿉니다.\n\n"
      + "- **약관 동의를 마친 계정만** 합니다(`CONSENT_REQUIRED`). 온보딩(이룸이 등록)은 건너뛸 수 있습니다.\n"
      + "- 소문자로 보내도 되고 사이 공백·하이픈이 있어도 됩니다 (`a7k-3m9` → `A7K3M9`).\n"
      + "- 합류하면 **가입 때 자동으로 생긴 빈 이룸이(이름·도움 목표·일과·연결된 이룸이 휴대폰이 모두 없고 혼자 돌보는 것)는 지웁니다.** "
      + "지운 id 는 `removedProfileIds` 로 알려줍니다. 앱은 `GET /api/member/me` 로 다시 읽습니다.\n"
      + "- 이미 함께하는 사람이 넣으면(자기가 낸 코드 포함) `409 PROFILE_ALREADY_GUARDIAN` 이고 코드는 쓰이지 않습니다.\n"
      + "- 한 코드는 한 번만 쓸 수 있습니다. 두 사람이 동시에 넣으면 한 명만 합류하고 다른 한 명은 `404 PROFILE_INVITE_NOT_FOUND` 입니다.\n"
      + "- 없는 코드와 이미 쓴·폐기된 코드는 **같은 응답**(404)입니다 — 존재 여부를 흘리지 않습니다.\n"
      + "- 이미 쓰였거나 폐기된 코드에 5회 틀리면 그 코드는 막힙니다. 계정당 10분에 10번까지 시도할 수 있고 넘으면 429 입니다.\n"
      + "- 내가 나간 이룸이에 다시 초대받아 들어올 수 있습니다. 나가면서 지워진 내 일과는 돌아오지 않습니다.",
    security = @SecurityRequirement(name = "bearerAuth")
  )
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "합류 성공"),
    @ApiResponse(responseCode = "400", description = "이름이 20자를 넘거나 제어 문자가 섞임 (INVALID_INPUT_VALUE)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "약관 동의 전(CONSENT_REQUIRED) 또는 이룸이 휴대폰(DEVICE_LINK_FORBIDDEN_FOR_ELUMI)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "404", description = "코드가 맞지 않음·이미 씀·폐기됨·이룸이가 그사이 지워짐 (PROFILE_INVITE_NOT_FOUND)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "409", description = "이미 함께하는 이룸이 (PROFILE_ALREADY_GUARDIAN)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "410", description = "코드 만료 (PROFILE_INVITE_EXPIRED)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "429", description = "시도가 너무 잦거나 한 코드에 5번 틀림 (PROFILE_INVITE_TOO_MANY_ATTEMPTS)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<ProfileJoinResponse> redeemInvite(Authentication authentication, RedeemProfileInviteRequest request);

  @Operation(
    summary = "함께하는 사람 목록 (연결된 보호자)",
    description = "이 이룸이를 함께 돌보는 사람들을 먼저 합류한 차례로 줍니다. 나도 한 줄로 들어 있고 `me=true` 입니다.\n\n"
      + "다른 보호자의 계정 정보(아이디 등)는 내려가지 않습니다. 이 이룸이 안에서 부르는 이름(`displayName`)과 표시(`kind`)만 있습니다. "
      + "이름이 비어 있으면 앱이 \"보호자\"로 부릅니다.",
    security = @SecurityRequirement(name = "bearerAuth")
  )
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "조회 성공"),
    @ApiResponse(responseCode = "403", description = "이룸이 휴대폰이거나 이 이룸이에 연결돼 있지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<GuardianListResponse> listGuardians(Authentication authentication, String profileId);

  @Operation(
    summary = "내 이름·표시 고치기 (연결된 보호자 · 자기만)",
    description = "내가 이 이룸이에서 불리는 이름(`displayName`)과 표시(`kind`: `GUARDIAN` 가족 보호자 · `CAREGIVER` 센터 선생님 등)를 고칩니다.\n\n"
      + "- 남의 것은 고칠 수 없습니다. 대상이 항상 \"나\"입니다.\n"
      + "- 보낸 항목만 바뀝니다. `displayName` 을 빈 문자열로 보내면 이름을 지웁니다. 둘 다 보내지 않으면 400 입니다.\n"
      + "- `kind` 는 화면에서 부르는 이름일 뿐 **권한에 쓰이지 않습니다.**",
    security = @SecurityRequirement(name = "bearerAuth")
  )
  @ApiResponses({
    @ApiResponse(responseCode = "200", description = "고침"),
    @ApiResponse(responseCode = "400", description = "보낸 항목이 없거나 이름이 20자를 넘음 (INVALID_INPUT_VALUE)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class))),
    @ApiResponse(responseCode = "403", description = "이룸이 휴대폰이거나 이 이룸이에 연결돼 있지 않음",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<GuardianResponse> updateMyGuardian(
    Authentication authentication, String profileId, GuardianUpdateRequest request);

  @Operation(
    summary = "이 이룸이에서 나가기 (연결된 보호자 · 자기만)",
    description = "내가 이 이룸이에서 나갑니다. **한 사람이 나가면 자기 것만 지웁니다.** 한 트랜잭션이라 도중에 실패하면 전부 되돌립니다.\n\n"
      + "| 지워지는 것 | 남는 것 |\n|---|---|\n"
      + "| 나와 이 이룸이의 관계 · **내가 만든 이 이룸이의 일과**(승인 전 포함, 단계·그림 포함) · 내가 붙인 이 이룸이의 이룸이 휴대폰 연결과 세션 · 내가 낸 초대 코드 | 이룸이 · 다른 보호자의 일과 · **별** |\n"
      + "| **마지막 보호자였다면** 위에 더해 이룸이(도움 목표 포함) · 남은 휴대폰 연결과 세션 · 남은 초대 코드 | — |\n\n"
      + "- 이룸이가 지금 내 일과를 수행 중이면 이룸이 휴대폰의 다음 요청은 404 입니다.\n"
      + "- 내가 붙인 이룸이 휴대폰은 끊깁니다. 남은 보호자가 새 연결 암호로 다시 붙입니다.\n"
      + "- 나간 뒤 이 이룸이가 연결된 이룸이의 마지막이었다면 `GET /api/member/me` 의 `profiles` 가 빈 배열이 되고 "
      + "이룸이가 필요한 API 는 `404 PROFILE_NOT_FOUND` 입니다 — 앱이 이룸이 등록으로 보냅니다.",
    security = @SecurityRequirement(name = "bearerAuth")
  )
  @ApiResponses({
    @ApiResponse(responseCode = "204", description = "나감"),
    @ApiResponse(responseCode = "403", description = "이룸이 휴대폰이거나 이 이룸이에 연결돼 있지 않음 (이미 나간 뒤 다시 부른 경우 포함)",
      content = @Content(schema = @Schema(implementation = ErrorResponse.class)))
  })
  ResponseEntity<Void> leave(Authentication authentication, String profileId);
}
