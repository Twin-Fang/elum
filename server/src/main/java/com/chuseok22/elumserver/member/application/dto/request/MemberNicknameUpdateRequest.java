package com.chuseok22.elumserver.member.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

@Schema(description = "아이 호칭 설정 요청")
public record MemberNicknameUpdateRequest(

  @Schema(description = "아이 호칭(별명)", example = "하늘이")
  @NotBlank(message = "nickname은 필수입니다.")
  @Size(max = 50, message = "nickname은 50자 이하여야 합니다.")
  String nickname
) {

}
