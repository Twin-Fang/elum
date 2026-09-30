package com.chuseok22.elumserver.adreward.application.dto.response;

import com.chuseok22.elumserver.adreward.application.service.AdRewardSessionStatus;
import com.chuseok22.elumserver.adreward.core.AdRewardRejectReason;
import com.chuseok22.elumserver.adreward.core.AdRewardStatus;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "광고 보상 세션의 상태")
public record AdRewardSessionStatusResponse(
  @Schema(description = "PENDING(콜백을 기다림) · GRANTED(지급됨) · REJECTED(주지 않음) · EXPIRED(시간이 지남)", example = "GRANTED")
  AdRewardStatus status,
  @Schema(description = "지급된 크레딧. 지급되지 않았으면 0", example = "2")
  int grantedCredits,
  @Schema(description = "REJECTED 일 때만 있다: DISABLED · AD_UNIT · NOT_PENDING · EXPIRED · FROZEN · DAILY_LIMIT",
    nullable = true, example = "DAILY_LIMIT")
  AdRewardRejectReason reason
) {

  public static AdRewardSessionStatusResponse from(AdRewardSessionStatus status) {
    return new AdRewardSessionStatusResponse(status.status(), status.grantedCredits(), status.reason());
  }
}
