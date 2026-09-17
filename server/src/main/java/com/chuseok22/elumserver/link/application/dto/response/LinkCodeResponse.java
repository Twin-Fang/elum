package com.chuseok22.elumserver.link.application.dto.response;

import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;

@Schema(description = "연결 암호 발급 결과")
public record LinkCodeResponse(

  @Schema(description = "여섯 글자 연결 암호. 화면에 3-3으로 묶어 크게 보여준다. "
    + "이 응답이 원문이 나가는 유일한 자리이며 서버에는 해시만 남는다.", example = "A7K3M9")
  String code,

  @Schema(description = "이 시각이 지나면 쓸 수 없다 (발급 + 10분)", example = "2026-09-18T10:40:00")
  LocalDateTime expiresAt,

  @Schema(description = "남은 초. 화면이 `10분 동안 쓸 수 있어요`를 계산하는 데 쓴다", example = "600")
  long expiresInSeconds
) {

}
