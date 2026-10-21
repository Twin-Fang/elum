package com.chuseok22.elumserver.adreward.application.service;

import com.chuseok22.elumserver.adreward.core.AdRewardRejectReason;
import com.chuseok22.elumserver.adreward.core.AdRewardStatus;
import java.time.LocalDateTime;
import java.util.Collection;

/**
 * 관리자 세션 검색 조건: 만든 기간[from, to), 회원, 보이는 상태, 거절 사유
 *
 * @param memberIds       null 이면 회원 조건 없음, 비어 있으면 결과 0건
 * @param effectiveStatus 보이는 상태 (PENDING 은 아직 유효한 것만, EXPIRED 는 콜백 없이 지난 PENDING 포함). null 이면 전체
 * @param rejectReason    null 이면 전체
 * @param now             만료 판정 기준 시각
 */
public record AdRewardSessionSearch(
  LocalDateTime from,
  LocalDateTime to,
  Collection<String> memberIds,
  AdRewardStatus effectiveStatus,
  AdRewardRejectReason rejectReason,
  LocalDateTime now
) {

}
