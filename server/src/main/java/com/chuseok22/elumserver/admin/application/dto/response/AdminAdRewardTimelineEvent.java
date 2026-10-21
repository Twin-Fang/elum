package com.chuseok22.elumserver.admin.application.dto.response;

import java.time.LocalDateTime;

/**
 * 광고 보상 상세 타임라인 한 칸: 시각, 제목, 설명, 색(daisyUI 이름: success·error·warning·info·neutral)
 *
 * @param isExpected 아직 오지 않은 예정 시각 (대기 중 세션의 유효 시간 끝)
 */
public record AdminAdRewardTimelineEvent(
  LocalDateTime at, String title, String description, String tone, boolean isExpected
) {

}
