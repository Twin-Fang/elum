package com.chuseok22.elumserver.auth.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "로그인 요청")
public record LoginRequest(

  @Schema(description = "회원가입 시 등록한 아이디", example = "chuseok22")
  String username,

  @Schema(description = "회원가입 시 등록한 비밀번호", example = "myStrongPassword1!")
  String password
) {

}
