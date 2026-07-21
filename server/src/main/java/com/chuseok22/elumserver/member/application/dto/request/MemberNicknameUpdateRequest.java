package com.chuseok22.elumserver.member.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "아이 호칭 설정 요청")
public record MemberNicknameUpdateRequest(

  @Schema(description = "아이 호칭(별명)", example = "하늘이")
  String nickname
) {

}
