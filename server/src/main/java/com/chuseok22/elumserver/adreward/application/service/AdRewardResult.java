package com.chuseok22.elumserver.adreward.application.service;

import com.chuseok22.elumserver.adreward.core.AdRewardRejectReason;

/// 콜백 처리 결과와, 거절이면 그 사유.
public record AdRewardResult(AdRewardOutcome outcome, AdRewardRejectReason reason) {

  public static AdRewardResult granted() {
    return new AdRewardResult(AdRewardOutcome.GRANTED, null);
  }

  public static AdRewardResult duplicate() {
    return new AdRewardResult(AdRewardOutcome.DUPLICATE, null);
  }

  public static AdRewardResult ignored() {
    return new AdRewardResult(AdRewardOutcome.IGNORED, null);
  }

  public static AdRewardResult rejected(AdRewardRejectReason reason) {
    return new AdRewardResult(AdRewardOutcome.REJECTED, reason);
  }
}
