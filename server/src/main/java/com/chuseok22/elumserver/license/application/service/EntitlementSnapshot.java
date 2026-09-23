package com.chuseok22.elumserver.license.application.service;

import com.chuseok22.elumserver.license.core.PlanType;

/**
 * 지금 이 계정이 가진 권한 전부. 클라이언트가 화면마다 따로 묻지 않도록 한 번에 내려준다.
 *
 * <p>수치 한도는 -1이면 무제한이다.
 */
public record EntitlementSnapshot(
  PlanType plan,
  boolean aiImageGeneration,
  boolean adsRemoved,
  int routineCreatePerDay,
  int routineCreatePerWeek,
  int routineMaxCount,
  int profileMaxCount,
  int historyRetentionDays
) {

}
