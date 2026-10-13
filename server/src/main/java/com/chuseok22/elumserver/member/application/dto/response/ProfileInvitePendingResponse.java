package com.chuseok22.elumserver.member.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;

@Schema(description = "내가 이 이룸이에 낸 미사용 초대 코드의 상태")
public record ProfileInvitePendingResponse(

  @Schema(description = "쓰이지도 폐기되지도 않았고 아직 만료 전인 초대 코드의 만료 시각. 그런 코드가 없으면 null",
    example = "2026-10-01T10:40:00", nullable = true)
  LocalDateTime expiresAt
) {

}
