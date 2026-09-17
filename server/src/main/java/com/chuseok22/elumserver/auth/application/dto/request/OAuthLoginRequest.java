package com.chuseok22.elumserver.auth.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

@Schema(description = "소셜 로그인 요청")
public record OAuthLoginRequest(

  @Schema(description = """
    제공자 SDK로 로그인해 받은 토큰.

    - 카카오·네이버: 액세스 토큰
    - 구글·애플: ID 토큰(JWT)

    서버는 이 토큰을 제공자에게 확인시킨 뒤 버립니다. 저장하지 않습니다.
    """, example = "ya29.a0AfH6SMBx...")
  @NotBlank
  String token
) {

}
