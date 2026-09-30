package com.chuseok22.elumserver.adreward.application.dto.response;

import com.chuseok22.elumserver.adreward.application.service.AdRewardSessionInfo;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;

@Schema(description = "광고 보상 세션")
public record AdRewardSessionResponse(
  @Schema(description = "광고를 요청할 때 customData 로 실어 보내는 값. 서버가 발급한 한 번용 값이다", example = "Zx3q…")
  String nonce,
  @Schema(description = "이 시각까지 시청 콜백이 오면 지급한다(한국 시각)", example = "2026-09-30T15:30:00")
  LocalDateTime expiresAt,
  @Schema(description = "시청 1회당 지급 크레딧", example = "2")
  int creditsPerView,
  @Schema(description = "이 세션을 포함해 오늘 더 받을 수 있는 횟수", example = "5")
  int remainingToday
) {

  public static AdRewardSessionResponse from(AdRewardSessionInfo info) {
    return new AdRewardSessionResponse(info.nonce(), info.expiresAt(), info.creditsPerView(), info.remainingToday());
  }
}
