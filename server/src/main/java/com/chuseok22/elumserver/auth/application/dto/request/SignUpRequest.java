package com.chuseok22.elumserver.auth.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

@Schema(description = "회원가입 요청")
public record SignUpRequest(

  @NotBlank(message = "아이디는 필수입니다.")
  String username,

  @NotBlank(message = "비밀번호는 필수입니다.")
  String password
) {

}
