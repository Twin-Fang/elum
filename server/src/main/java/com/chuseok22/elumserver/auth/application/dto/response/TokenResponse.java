package com.chuseok22.elumserver.auth.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "로그인 성공 응답 (토큰 발급 결과)")
public record TokenResponse(

  @Schema(description = "인증용 JWT accessToken. 이후 인증이 필요한 요청의 `Authorization` 헤더에 "
    + "`Bearer {accessToken}` 형식으로 담아 전송해야 합니다.",
    example = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJiM2IxZTJhMC0xMjM0LTRkNTYtOWFiYy0xMjM0NTY3ODkwYWIifQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c")
  String accessToken,

  @Schema(description = "토큰 타입. 항상 \"Bearer\" 고정값이며, Authorization 헤더 접두사로 사용합니다.",
    example = "Bearer")
  String tokenType,

  @Schema(description = "accessToken의 유효 기간(밀리초). 발급 시점 기준이며, 클라이언트는 이 값으로 "
    + "토큰 만료 시점을 계산해 재로그인 UX를 처리할 수 있습니다.",
    example = "86400000")
  long expiresIn,

  @Schema(description = "accessToken 재발급용 refreshToken. 안전한 저장소(Keychain/Keystore)에 보관하고 "
    + "`POST /api/auth/refresh`로 갱신합니다. 갱신할 때마다 값이 바뀌므로 응답으로 받은 새 값으로 "
    + "덮어써야 합니다. 이전 값을 다시 보내면 탈취로 간주해 모든 세션이 끊깁니다.",
    example = "mZ3xQv7K9tR2pL5nW8cY4bH6jF1dS0aG")
  String refreshToken
) {

}
