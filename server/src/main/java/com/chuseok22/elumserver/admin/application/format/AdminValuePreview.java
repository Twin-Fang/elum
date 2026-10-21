package com.chuseok22.elumserver.admin.application.format;

/**
 * 관리자 화면에 비밀에 가까운 값(광고 nonce·transaction id 등)을 앞 몇 글자만 보이는 형태로 (값 없으면 "-")
 * 서버 로그의 nonce 미리보기(앞 6자)와 같은 길이라 로그와 대조할 수 있다
 */
public final class AdminValuePreview {

  // 보여 줄 앞 글자 수
  public static final int VISIBLE_PREFIX_LENGTH = 6;
  private static final String EMPTY_TEXT = "-";
  private static final String ELLIPSIS = "…";

  private AdminValuePreview() {
  }

  /// 값 > "앞 6자…" (6자 이하 값도 끝에 … 를 붙여 전체 값처럼 보이지 않게)
  public static String previewOf(String value) {
    if (value == null || value.isBlank()) {
      return EMPTY_TEXT;
    }
    return value.substring(0, Math.min(VISIBLE_PREFIX_LENGTH, value.length())) + ELLIPSIS;
  }
}
