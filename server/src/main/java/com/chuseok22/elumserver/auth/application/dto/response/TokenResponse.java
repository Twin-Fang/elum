package com.chuseok22.elumserver.auth.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "로그인 성공 응답 (accessToken 발급 결과)")
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
    example = "3600000")
  long expiresIn
) {

}
