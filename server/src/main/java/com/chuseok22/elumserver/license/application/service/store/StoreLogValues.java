package com.chuseok22.elumserver.license.application.service.store;

/**
 * 로그용 값 정리: 외부에서 온 id·토큰 > 허용 문자 밖은 ?, 앞 8자 + 길이만 (토큰 원문이 로그에 남지 않게)
 */
public final class StoreLogValues {

  private static final String NON_ID_CHARACTERS = "[^0-9A-Za-z._-]";
  private static final String REPLACEMENT = "?";
  private static final int VISIBLE_PREFIX_LENGTH = 8;

  private StoreLogValues() {
  }

  /// 구매 키·거래 id·회원 id > "abcd1234…(36)"
  public static String mask(String value) {
    if (value == null) {
      return "-";
    }
    String cleaned = value.replaceAll(NON_ID_CHARACTERS, REPLACEMENT);
    if (cleaned.length() <= VISIBLE_PREFIX_LENGTH) {
      return cleaned;
    }
    return cleaned.substring(0, VISIBLE_PREFIX_LENGTH) + "…(" + cleaned.length() + ")";
  }
}
