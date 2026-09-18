package com.chuseok22.elumserver.license.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 요금제.
 *
 * <p>구독 행이 없는 계정은 {@link #FREE}로 본다. 기존 회원을 옮기는 작업이 필요 없고,
 * 어떤 경로로 가입했든 로그인하는 사람은 일단 Free가 된다.
 *
 * <p>기관용 요금제(ENTERPRISE)는 두지 않았다. "이룸이 몇 명까지"를 권한 값으로 두면
 * 기관 계정은 그 숫자가 큰 계정일 뿐이라 별도 등급이 필요 없다.
 */
@Getter
@AllArgsConstructor
public enum PlanType {

  FREE("무료"),
  PRO("프로"),
  ;

  private final String label;
}
