package com.chuseok22.elumserver.credit.application.service.purchase;

import com.chuseok22.elumserver.systemconfig.core.CreditPackListFormat;
import com.chuseok22.elumserver.systemconfig.core.CreditPackListFormat.Pack;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * 꾸러미 판매 설정 점검: 규칙 6개(건너뛴 항목, 상품 0개, 인기 누락, ID 중복, 전체 스위치, 환불 재확인)
 * 부수효과 없는 순수 계산, 위험한 설정마다 경고 한 줄 (이상 없으면 정상 한 줄)
 */
public final class CreditPackHealthCheck {

  private static final String ITEM_DELIMITER = ",";
  private static final String ITEM_VALUE_DELIMITER = ":";

  private CreditPackHealthCheck() {
  }

  /// 점검 결과 한 줄: 경고 여부 + 관리자에게 보일 문장
  public record Finding(boolean isWarning, String message) {

  }

  /// 점검 입력: 스위치 3개, 상품 목록 원문, 인기 상품 ID, 환불 재확인 켜짐
  public record Snapshot(
    boolean isAllSaleEnabled,
    boolean isAppleSaleEnabled,
    boolean isGoogleSaleEnabled,
    String productsText,
    String popularProductId,
    boolean isRefundRecheckEnabled
  ) {

    boolean isAnySaleEnabled() {
      return isAllSaleEnabled || isAppleSaleEnabled || isGoogleSaleEnabled;
    }
  }

  /// 설정 > 점검 결과 (경고가 없으면 정상 한 줄)
  public static List<Finding> check(Snapshot snapshot) {
    List<Finding> findings = new ArrayList<>();
    String productsText = snapshot.productsText() == null ? "" : snapshot.productsText();
    List<Pack> packs = CreditPackListFormat.parse(productsText);
    List<String> rawItems = rawItemsOf(productsText);

    // 목록 (읽히지 않은 항목, 중복 ID, 상품 0개)
    if (rawItems.size() > packs.size() && !hasDuplicateProductId(rawItems)) {
      findings.add(warning("형식이 틀려 건너뛰는 항목이 있어요 (" + (rawItems.size() - packs.size()) + "개). 상품ID:개수 형식을 확인하세요"));
    }
    if (hasDuplicateProductId(rawItems)) {
      findings.add(warning("같은 상품 ID 가 두 번 있어요. 먼저 나온 것만 쓰여요"));
    }
    if (packs.isEmpty() && snapshot.isAnySaleEnabled()) {
      findings.add(warning("판매가 켜져 있는데 꾸러미 상품이 하나도 없어요. 앱에는 꾸러미가 보이지 않아요"));
    }

    // 인기 상품 (목록에 없으면 인기 표시가 안 붙음)
    String popular = snapshot.popularProductId() == null ? "" : snapshot.popularProductId().trim();
    if (!popular.isEmpty() && packs.stream().noneMatch(pack -> pack.productId().equals(popular))) {
      findings.add(warning("인기 상품 " + popular + " 이 꾸러미 목록에 없어요. 인기 표시가 붙지 않아요"));
    }

    // 스위치 · 환불 (전체 스위치는 스토어별 스위치를 건너뛰고 옛 앱까지 판매)
    if (snapshot.isAllSaleEnabled()) {
      findings.add(warning("전체 판매 스위치가 켜져 있어요. 스토어 스위치와 상관없이 모든 스토어와 옛 앱에서 팔려요"));
    }
    if (snapshot.isAnySaleEnabled() && !snapshot.isRefundRecheckEnabled()) {
      findings.add(warning("환불 재확인이 꺼져 있어요. 놓친 환불이 회수되지 않을 수 있어요"));
    }

    if (findings.isEmpty()) {
      findings.add(new Finding(false, "이상 없어요"));
    }
    return findings;
  }

  private static Finding warning(String message) {
    return new Finding(true, message);
  }

  /// 원문 > 비지 않은 항목 (앞뒤 공백 제거)
  private static List<String> rawItemsOf(String productsText) {
    List<String> items = new ArrayList<>();
    for (String item : productsText.split(ITEM_DELIMITER)) {
      if (!item.isBlank()) {
        items.add(item.trim());
      }
    }
    return items;
  }

  /// 상품 ID(콜론 앞)가 같은 항목이 둘 이상인가
  private static boolean hasDuplicateProductId(List<String> rawItems) {
    Set<String> seenProductIds = new HashSet<>();
    for (String item : rawItems) {
      String productId = item.split(ITEM_VALUE_DELIMITER, 2)[0].trim();
      if (!seenProductIds.add(productId)) {
        return true;
      }
    }
    return false;
  }
}
