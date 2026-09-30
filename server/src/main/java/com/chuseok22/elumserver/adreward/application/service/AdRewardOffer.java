package com.chuseok22.elumserver.adreward.application.service;

/**
 * 앱이 "광고 보고 더 만들기"를 보일지 정하는 값 (#463).
 *
 * @param enabled         지금 받을 수 있는가(켜져 있고, 오늘 남았고, 계정이 멈추지 않았다)
 * @param creditsPerView  시청 1회당 지급 크레딧
 * @param remainingToday  오늘 더 받을 수 있는 횟수
 */
public record AdRewardOffer(boolean enabled, int creditsPerView, int remainingToday) {

}
