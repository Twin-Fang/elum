package com.chuseok22.elumserver.adreward.application.service;

import com.chuseok22.elumserver.adreward.core.AdRewardRejectReason;
import com.chuseok22.elumserver.adreward.core.AdRewardStatus;

/// 앱이 광고를 본 뒤 폴링하는 세션 상태 (#463). reason 은 거절일 때만 있다.
public record AdRewardSessionStatus(AdRewardStatus status, int grantedCredits, AdRewardRejectReason reason) {

}
