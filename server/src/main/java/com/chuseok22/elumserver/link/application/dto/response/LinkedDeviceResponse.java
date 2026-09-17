package com.chuseok22.elumserver.link.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;

@Schema(description = "연결된 이룸이 휴대폰 한 대")
public record LinkedDeviceResponse(

  @Schema(description = "이 연결의 식별자. 끊을 때 이 값을 쓴다", example = "b3b1e2a0-1234-4d56-9abc-1234567890ab")
  String linkId,

  @Schema(description = "연결된 시각. 설정 화면이 `9월 18일부터`로 보여준다", example = "2026-09-18T10:31:00")
  LocalDateTime linkedAt
) {

}
