package com.chuseok22.elumserver.license.application.service;

import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.license.core.PlanType;

/**
 * 권한을 묻는 <b>단 하나의 통로</b>.
 *
 * <p>기능 코드는 이 인터페이스만 부르고 내부가 설정 값인지 테이블인지 모른다. 플랜이
 * 셋 이상 되거나 기관별 커스텀 한도가 필요해져 구현을 갈아끼워도 <b>부르는 쪽은 한 줄도
 * 바뀌지 않는다.</b>
 *
 * <p>예외는 여기서 던지지 않는다. 한도를 넘었을 때 무엇을 할지는 기능마다 다르기
 * 때문이다 — 일과 생성은 거부하지만 AI 삽화는 거부 대신 픽토그램으로 내려간다.
 */
public interface EntitlementService {

  /// 지금 유효한 플랜. 구독이 없거나 만료됐으면 FREE.
  PlanType planOf(String memberId);

  /// 켜짐/꺼짐 권한.
  boolean isAllowed(String memberId, Entitlement flag);

  /// 수치 한도. {@link Entitlement#UNLIMITED}(-1)이면 무제한.
  int limitOf(String memberId, Entitlement limit);

  /// 현재 사용량이 한도 안인가. 무제한이면 언제나 true.
  boolean isWithinLimit(String memberId, Entitlement limit, long current);

  EntitlementSnapshot snapshot(String memberId);
}
