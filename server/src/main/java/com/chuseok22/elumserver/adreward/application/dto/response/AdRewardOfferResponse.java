package com.chuseok22.elumserver.adreward.application.dto.response;

import com.chuseok22.elumserver.adreward.application.service.AdRewardOffer;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "광고 보고 더 만들기를 보일지 정하는 값")
public record AdRewardOfferResponse(
  @Schema(description = "지금 광고로 크레딧을 받을 수 있는가. false 면 앱은 버튼을 보이지 않는다(꺼짐·오늘 상한·멈춘 계정)", example = "true")
  boolean enabled,
  @Schema(description = "광고 시청 1회당 지급 크레딧", example = "2")
  int creditsPerView,
  @Schema(description = "오늘 광고로 더 받을 수 있는 횟수(한국 시각 0시 시작)", example = "5")
  int remainingToday
) {

  public static AdRewardOfferResponse from(AdRewardOffer offer) {
    return new AdRewardOfferResponse(offer.enabled(), offer.creditsPerView(), offer.remainingToday());
  }
}
