package com.chuseok22.elumserver.member.core;

import java.util.Locale;

/**
 * 화면 표시용 이메일 가리기: 아이디 앞 2자 + *** + @도메인 (예: ab***@gmail.com)
 * 이메일 없음·형식 깨짐·애플 숨김 주소 > null (앱이 "이메일 비공개"로 표시)
 */
public final class EmailMasker {

  // 아이디 부분에서 보여 주는 앞 글자 수
  private static final int VISIBLE_LOCAL_PART_LENGTH = 2;
  private static final String MASK = "***";
  // 애플 "내 이메일 숨기기" 중계 주소 도메인 — 무작위 문자열이라 보여 줘도 구분에 도움 안 됨
  private static final String APPLE_PRIVATE_RELAY_DOMAIN = "privaterelay.appleid.com";

  private EmailMasker() {
  }

  public static String mask(String email) {
    if (email == null) {
      return null;
    }
    String trimmedEmail = email.strip();
    int atIndex = trimmedEmail.lastIndexOf('@');
    if (atIndex <= 0 || atIndex == trimmedEmail.length() - 1) {
      return null;
    }
    String localPart = trimmedEmail.substring(0, atIndex);
    String domain = trimmedEmail.substring(atIndex + 1);
    if (domain.toLowerCase(Locale.ROOT).endsWith(APPLE_PRIVATE_RELAY_DOMAIN)) {
      return null;
    }
    // 아이디가 2자 이하면 첫 글자만 보여 줌 (전부 드러나지 않게)
    int visibleLength = localPart.length() > VISIBLE_LOCAL_PART_LENGTH ? VISIBLE_LOCAL_PART_LENGTH : 1;
    return localPart.substring(0, visibleLength) + MASK + "@" + domain;
  }
}
