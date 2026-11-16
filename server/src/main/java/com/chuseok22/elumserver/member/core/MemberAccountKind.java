package com.chuseok22.elumserver.member.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 계정 종류 4개 (#1436): 일반, 내부(운영자), 테스트, 스토어 심사
 * 관리자 숫자(가입·방문·사용 분석)는 기본으로 일반 계정만 셈 > 조건은 COUNTED_MEMBER_SQL 한곳
 */
@Getter
@AllArgsConstructor
public enum MemberAccountKind {

  NORMAL("일반"),
  INTERNAL("내부"),
  TEST("테스트"),
  STORE_REVIEW("스토어 심사"),
  ;

  /// 숫자에 세는 회원 조건 (native SQL, member 표 별칭 m): 일반 계정만. 집계 쿼리는 모두 이 조건을 붙임
  public static final String COUNTED_MEMBER_SQL = "m.account_kind = 'NORMAL'";

  private final String label;

  /** 화면 값 > 종류 (모르는 값·빈 값은 null) */
  public static MemberAccountKind fromParameterOrNull(String value) {
    if (value == null) {
      return null;
    }
    for (MemberAccountKind kind : values()) {
      if (kind.name().equals(value.trim())) {
        return kind;
      }
    }
    return null;
  }
}
