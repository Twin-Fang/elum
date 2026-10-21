package com.chuseok22.elumserver.admin.application.format;

/**
 * 로그용 id 정리: 주소·폼에서 온 id > UUID 문자(16진수, -) 밖은 ? (로그 줄 위조 방지)
 */
public final class AdminLogIds {

  private static final String NON_UUID_CHARACTERS = "[^0-9a-fA-F-]";
  private static final String REPLACEMENT = "?";

  private AdminLogIds() {
  }

  public static String toLoggableId(String id) {
    return id == null ? null : id.replaceAll(NON_UUID_CHARACTERS, REPLACEMENT);
  }
}
