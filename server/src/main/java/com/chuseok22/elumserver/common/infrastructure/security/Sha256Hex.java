package com.chuseok22.elumserver.common.infrastructure.security;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/**
 * 문자열(UTF-8) > SHA-256 소문자 hex 64자
 * 쓰는 곳 5개: 로그인 토큰 저장 해시, 연결 암호·초대 코드 해시, 크레딧 신원 키, 카드 음성 열쇠, 푸시 접기 키
 */
public final class Sha256Hex {

  private static final String ALGORITHM = "SHA-256";

  private Sha256Hex() {
  }

  public static String hexOf(String text) {
    try {
      byte[] digest = MessageDigest.getInstance(ALGORITHM).digest(text.getBytes(StandardCharsets.UTF_8));
      return HexFormat.of().formatHex(digest);
    } catch (NoSuchAlgorithmException e) {
      // JDK 표준 필수 알고리즘이라 일어나지 않음
      throw new IllegalStateException(ALGORITHM + " unavailable", e);
    }
  }
}
