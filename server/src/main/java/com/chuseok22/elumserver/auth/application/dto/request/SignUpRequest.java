package com.chuseok22.elumserver.auth.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "회원가입 요청")
public record SignUpRequest(

  String username,

  String password
) {

}
