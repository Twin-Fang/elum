package com.chuseok22.elumserver.auth.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

@Schema(description = "회원가입 요청")
public record SignUpRequest(

  @Schema(description = "로그인에 사용할 아이디. 4~20자, 서비스 내에서 중복될 수 없습니다.",
    example = "chuseok22", minLength = 4, maxLength = 20)
  @NotBlank(message = "아이디는 필수입니다.")
  @Size(min = 4, max = 20, message = "아이디는 4자 이상 20자 이하로 입력해주세요.")
  String username,

  @Schema(description = "로그인 비밀번호. 8~64자. 서버 저장 시 BCrypt로 해시되며 평문으로는 저장·응답되지 않습니다.",
    example = "myStrongPassword1!", minLength = 8, maxLength = 64)
  @NotBlank(message = "비밀번호는 필수입니다.")
  @Size(min = 8, max = 64, message = "비밀번호는 8자 이상 64자 이하로 입력해주세요.")
  String password
) {

}
