package com.chuseok22.elumserver.member.infrastructure.entity;

/**
 * 함께 돌보는 사람을 화면에서 어떻게 부를지 (다중 보호자 명세 4-1).
 *
 * <p>권한 차이가 아니다. 보호자 사이에 윗사람을 두지 않기로 했다(명세 11장). 권한 차이가
 * 필요해지면 그때 이 값을 근거로 더한다.
 */
public enum GuardianKind {
  /** 가족 보호자 */
  GUARDIAN,
  /** 센터 선생님 등 기관 지도자 */
  CAREGIVER
}
