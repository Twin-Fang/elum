package com.chuseok22.elumserver.link.core;

import java.security.SecureRandom;

/**
 * 연결 암호 — 보호자가 불러주고 이룸이가 받아적는 여섯 글자.
 *
 * <p>사람의 입을 거치므로 <b>헷갈리는 글자를 아예 만들지 않는다.</b> {@code 0}과 {@code O},
 * {@code 1}과 {@code I}·{@code L}이 섞이면 그 자리에서 막힌다. {@code U}는 {@code V}와
 * 발음이 헷갈려 뺀다.
 *
 * <p>남은 30자로 6자리면 7억 가지다. 유효 시간이 10분이라 이 정도로 충분하지만,
 * 추측을 막는 것은 길이가 아니라 시도 횟수 제한이다 ({@code DeviceLinkService}).
 */
public final class LinkCode {

  /** 0 O 1 I L U 를 뺀 30자. */
  public static final String ALPHABET = "23456789ABCDEFGHJKMNPQRSTVWXYZ";

  public static final int LENGTH = 6;

  private static final SecureRandom RANDOM = new SecureRandom();

  private LinkCode() {
  }

  public static String generate() {
    StringBuilder sb = new StringBuilder(LENGTH);
    for (int i = 0; i < LENGTH; i++) {
      sb.append(ALPHABET.charAt(RANDOM.nextInt(ALPHABET.length())));
    }
    return sb.toString();
  }

  /**
   * 입력을 비교 가능한 모양으로 맞춘다.
   *
   * <p>소문자로 쳐도 되고, 불러주다 띄어쓴 것(`A7K 3M9`)도 받는다 — 화면이 3-3으로 묶어
   * 보여주므로 그대로 따라 치는 사람이 있다.
   */
  public static String normalize(String raw) {
    if (raw == null) {
      return "";
    }
    return raw.replaceAll("[\\s-]", "").toUpperCase();
  }

  /** 우리가 만들 수 있는 모양인가. 길이·문자만 본다 (존재 여부는 저장소가 판단). */
  public static boolean hasValidShape(String normalized) {
    if (normalized.length() != LENGTH) {
      return false;
    }
    for (int i = 0; i < normalized.length(); i++) {
      if (ALPHABET.indexOf(normalized.charAt(i)) < 0) {
        return false;
      }
    }
    return true;
  }
}
