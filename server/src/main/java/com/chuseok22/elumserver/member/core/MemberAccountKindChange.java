package com.chuseok22.elumserver.member.core;

/**
 * 계정 종류 변경 결과: 전 종류 > 새 종류 (같으면 바뀐 것 없음, 관리자 기록에 전후 값으로 남김)
 */
public record MemberAccountKindChange(MemberAccountKind previousKind, MemberAccountKind currentKind) {

  public boolean isChanged() {
    return previousKind != currentKind;
  }
}
