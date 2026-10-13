package com.chuseok22.elumserver.link.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;

@Schema(description = "연결된 이룸이 휴대폰 한 대")
public record LinkedDeviceResponse(

  @Schema(description = "이 연결의 식별자. 끊을 때 이 값을 쓴다", example = "b3b1e2a0-1234-4d56-9abc-1234567890ab")
  String linkId,

  @Schema(description = "연결된 시각. 설정 화면이 `9월 18일부터`로 보여준다", example = "2026-09-18T10:31:00")
  LocalDateTime linkedAt,

  @Schema(description = "기기 이름(모델명). 옛 앱이 연결했으면 null", example = "iPhone 16", nullable = true)
  String deviceName,

  @Schema(description = "이 연결 암호를 만든 보호자가 이 이룸이 안에서 불리는 이름. 이름이 없거나 알 수 없으면 null "
    + "(앱이 '보호자'로 부른다). 계정 식별자·이메일은 내려가지 않는다", example = "김선생님", nullable = true)
  String linkedByName,

  @Schema(description = "내가 만든 연결 암호로 붙은 휴대폰이면 true", example = "false")
  boolean linkedByMe
) {

}
