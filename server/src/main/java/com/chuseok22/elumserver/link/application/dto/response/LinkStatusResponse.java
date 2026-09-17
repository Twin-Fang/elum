package com.chuseok22.elumserver.link.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;

@Schema(description = "이룸이 휴대폰 연결 상태")
public record LinkStatusResponse(

  @Schema(description = "NONE(연결도 발급도 없음) · PENDING(암호 발급됨, 아직 안 씀) · LINKED(연결됨)",
    example = "LINKED")
  String state,

  @Schema(description = "연결된 시각. 설정 화면이 `9월 18일부터`로 보여준다. 연결 전에는 null",
    example = "2026-09-18T10:31:00")
  LocalDateTime linkedAt,

  @Schema(description = "발급된 암호의 만료 시각. PENDING일 때만 값이 있다")
  LocalDateTime expiresAt
) {

  public static final String STATE_NONE = "NONE";
  public static final String STATE_PENDING = "PENDING";
  public static final String STATE_LINKED = "LINKED";
}
