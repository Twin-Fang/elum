package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.credit.application.service.purchase.CreditPackHealthCheck.Finding;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 관리자 크레딧 > 꾸러미 화면 데이터: 판매 현황, 상품, 점검, 최근 7일, 변경 이력
 * 칸마다 독립 실패 (실패한 칸은 null, 코드는 failedCodes 에)
 */
public record AdminCreditPackView(
  SaleSection sale,
  ProductsSection products,
  List<Finding> findings,
  ActivitySection activity,
  List<HistoryRow> histories,
  List<String> failedCodes
) {

  /// 판매 현황: 전체 스위치(읽기 전용) + 스토어별 스위치
  public record SaleSection(boolean isAllSaleEnabled, List<StoreSale> stores) {

  }

  public record StoreSale(SubscriptionSource store, String label, boolean isEnabled) {

  }

  /// 상품 목록(설정 순서) + 인기 상품 ID
  public record ProductsSection(List<ProductRow> rows, String popularProductId) {

  }

  public record ProductRow(String productId, int credits, boolean isPopular) {

  }

  /// 최근 7일 구매·환불 건수
  public record ActivitySection(long purchaseCount, long refundCount) {

  }

  /// 꾸러미 설정 변경 이력 한 줄
  public record HistoryRow(String keyLabel, String oldValue, String newValue, String changedBy, String reason, LocalDateTime changedAt) {

  }

  /// 상품 편집 입력 한 줄 (틀린 값도 그대로 화면에 돌려주려고 문자열)
  public record DraftRow(String productId, String credits) {

  }
}
