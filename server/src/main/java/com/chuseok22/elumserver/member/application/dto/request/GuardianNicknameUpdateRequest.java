package com.chuseok22.elumserver.member.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "보호자 닉네임 변경 요청 (검사는 서버가 함: 2~16자, 한글·영문·숫자·하이픈)")
public record GuardianNicknameUpdateRequest(

  @Schema(description = "새 보호자 닉네임", example = "푸른하늘")
  String nickname
) {

}
