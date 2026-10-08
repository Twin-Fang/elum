package com.chuseok22.elumserver.adreward.application.service;

import java.time.LocalDateTime;

/// 새로 만든(또는 다시 쓰는) 세션. 앱은 nonce 를 광고 요청에 실어 보낸다.
public record AdRewardSessionInfo(String nonce, LocalDateTime expiresAt, int creditsPerView, int remainingToday) {

}
