package com.chuseok22.elumserver.systemconfig.core;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * 크레딧 꾸러미 목록 설정 형식: "상품ID:개수" 쉼표 목록 (예: elum_credit_50:50,elum_credit_150:150)
 * parse 는 읽을 때(모르는 항목은 건너뜀), invalidReason 은 저장할 때(하나라도 틀리면 거부) 쓴다
 */
public final class CreditPackListFormat {

  /// 꾸러미 한 개의 크레딧 상한 (오타로 수만 개가 적립되는 것을 막음)
  public static final int MAX_CREDITS_PER_PACK = 10_000;
  private static final String LIST_DELIMITER = ",";
  private static final Pattern PACK_PATTERN = Pattern.compile("^([A-Za-z0-9._-]{1,150}):(\\d{1,5})$");

  private CreditPackListFormat() {
  }

  /// 목록 하나의 꾸러미: 스토어 상품 ID + 적립 크레딧 개수
  public record Pack(String productId, int credits) {

  }

  /// 설정 문자열 > 꾸러미 (순서 유지, 형식이 틀린 항목·개수 범위 밖·중복 상품 ID 는 건너뜀)
  public static List<Pack> parse(String listText) {
    List<Pack> packs = new ArrayList<>();
    if (listText == null || listText.isBlank()) {
      return packs;
    }
    Set<String> seenProductIds = new LinkedHashSet<>();
    for (String item : listText.split(LIST_DELIMITER)) {
      Matcher matcher = PACK_PATTERN.matcher(item.trim());
      if (!matcher.matches()) {
        continue;
      }
      int credits = Integer.parseInt(matcher.group(2));
      if (credits < 1 || credits > MAX_CREDITS_PER_PACK || !seenProductIds.add(matcher.group(1))) {
        continue;
      }
      packs.add(new Pack(matcher.group(1), credits));
    }
    return packs;
  }

  /// 저장 전 검사: 통과면 null, 거부면 관리자에게 보일 이유
  public static String invalidReason(String listText) {
    if (listText == null || listText.isBlank()) {
      return null;
    }
    Set<String> seenProductIds = new LinkedHashSet<>();
    for (String item : listText.split(LIST_DELIMITER)) {
      String trimmed = item.trim();
      Matcher matcher = PACK_PATTERN.matcher(trimmed);
      if (!matcher.matches()) {
        return "상품ID:개수 형식이 아니에요: " + (trimmed.length() > 40 ? trimmed.substring(0, 40) + "…" : trimmed);
      }
      int credits = Integer.parseInt(matcher.group(2));
      if (credits < 1 || credits > MAX_CREDITS_PER_PACK) {
        return "크레딧 개수는 1~" + MAX_CREDITS_PER_PACK + " 사이예요: " + trimmed;
      }
      if (!seenProductIds.add(matcher.group(1))) {
        return "같은 상품 ID 가 두 번 있어요: " + matcher.group(1);
      }
    }
    return null;
  }

  /// 정리한 값 (항목 앞뒤 공백 제거, 빈 항목 제거)
  public static String normalize(String listText) {
    List<String> items = new ArrayList<>();
    for (String item : listText.split(LIST_DELIMITER)) {
      if (!item.isBlank()) {
        items.add(item.trim());
      }
    }
    return String.join(LIST_DELIMITER, items);
  }
}
