package com.chuseok22.elumserver.admin.application.format;

import com.chuseok22.elumserver.member.core.MemberAccountKind;

/**
 * 계정 종류 > 배지 색 (#1436): 내부 info, 테스트 warning, 스토어 심사 ghost, 일반은 배지 없음(null)
 * 회원 목록·회원 상세·대시보드 최근 가입이 같은 색을 씀
 */
public final class AdminAccountKindBadges {

  private AdminAccountKindBadges() {
  }

  public static String toneOf(MemberAccountKind kind) {
    if (kind == null) {
      return null;
    }
    return switch (kind) {
      case NORMAL -> null;
      case INTERNAL -> "info";
      case TEST -> "warning";
      case STORE_REVIEW -> "ghost";
    };
  }
}
