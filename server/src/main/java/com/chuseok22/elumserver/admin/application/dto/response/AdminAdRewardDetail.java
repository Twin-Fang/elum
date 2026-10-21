package com.chuseok22.elumserver.admin.application.dto.response;

import java.util.List;

/// 광고 보상 세션 상세: 한 건 + 타임라인 (세션 생성 > 콜백 수신 > 지급·거절·만료)
public record AdminAdRewardDetail(AdminAdRewardRow row, List<AdminAdRewardTimelineEvent> timeline) {

  public AdminAdRewardDetail {
    timeline = timeline == null ? List.of() : List.copyOf(timeline);
  }
}
