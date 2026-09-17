package com.chuseok22.elumserver.link.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;
import java.util.List;

@Schema(description = "이룸이 휴대폰 연결 상태")
public record LinkStatusResponse(

  @Schema(description = "연결된 휴대폰들. 최근에 연결된 것이 앞에 온다. 비어 있으면 아직 없다")
  List<LinkedDeviceResponse> devices,

  @Schema(description = "발급했고 아직 아무도 쓰지 않은 암호의 만료 시각. 없으면 null",
    example = "2026-09-18T10:40:00")
  LocalDateTime pendingExpiresAt
) {

  public boolean hasLinkedDevice() {
    return !devices.isEmpty();
  }
}
