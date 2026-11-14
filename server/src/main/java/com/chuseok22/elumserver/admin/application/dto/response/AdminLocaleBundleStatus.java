package com.chuseok22.elumserver.admin.application.dto.response;

import java.util.List;
import java.util.Map;

/**
 * 언어 문구 파일 한 벌의 상태: 채워진 키 수, ko 기준 빈 키 목록
 * 빈 키 = ko 에 있는데 이 언어 값이 없거나 공백
 */
public record AdminLocaleBundleStatus(int keyCount, List<String> missingKeys) {

  /** ko 맵 <-> 대상 맵 > 상태 (빈 키는 이름순) */
  public static AdminLocaleBundleStatus compareWithKo(Map<String, String> koTextByKey,
    Map<String, String> targetTextByKey) {
    int filledKeyCount = (int) targetTextByKey.values().stream().filter(text -> !isBlank(text)).count();
    List<String> missingKeys = koTextByKey.keySet().stream()
      .filter(key -> isBlank(targetTextByKey.get(key)))
      .sorted()
      .toList();
    return new AdminLocaleBundleStatus(filledKeyCount, missingKeys);
  }

  public int missingCount() {
    return missingKeys.size();
  }

  public boolean isComplete() {
    return missingKeys.isEmpty();
  }

  private static boolean isBlank(String text) {
    return text == null || text.isBlank();
  }
}
