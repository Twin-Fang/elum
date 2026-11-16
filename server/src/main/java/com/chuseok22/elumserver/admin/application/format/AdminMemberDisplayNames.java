package com.chuseok22.elumserver.admin.application.format;

/**
 * 관리자 화면 회원 표시 이름: 보호자 닉네임, 없으면 회원 id 앞 8자리 (사용 분석·대시보드 목록 공통)
 */
public final class AdminMemberDisplayNames {

  /// 닉네임이 없을 때 이름 대신 보일 회원 id 앞자리 수
  private static final int MEMBER_ID_PREFIX_LENGTH = 8;
  private static final String BLANK_TEXT = "-";

  private AdminMemberDisplayNames() {
  }

  public static String of(String nickname, String memberId) {
    if (nickname != null && !nickname.isBlank()) {
      return nickname;
    }
    return memberId == null ? BLANK_TEXT : memberId.substring(0, Math.min(MEMBER_ID_PREFIX_LENGTH, memberId.length()));
  }
}
