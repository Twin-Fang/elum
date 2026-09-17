package com.chuseok22.elumserver.auth.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

@Schema(description = "토큰 갱신 · 로그아웃 요청")
public record RefreshTokenRequest(

  @Schema(description = "로그인 때 받은 refreshToken. 갱신에 성공하면 새 값으로 바뀌므로 "
    + "응답으로 받은 값으로 반드시 덮어써야 합니다.",
    example = "mZ3xQv7K9tR2pL5nW8cY4bH6jF1dS0aG")
  @NotBlank
  String refreshToken
) {

}
