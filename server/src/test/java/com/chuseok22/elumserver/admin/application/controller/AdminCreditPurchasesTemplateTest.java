package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPurchaseRow;
import com.chuseok22.elumserver.admin.application.service.AdminCreditPurchaseService.RecheckOverview;
import com.chuseok22.elumserver.admin.application.list.AdminCreditPurchaseList;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.credit.core.CreditPurchaseStatus;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPurchase;
import com.chuseok22.elumserver.license.core.StoreRefundCheckFailureReason;
import com.chuseok22.elumserver.license.core.StoreRefundCheckTrigger;
import com.chuseok22.elumserver.license.core.StoreRefundOrigin;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StoreRefundCheckRun;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.test.util.ReflectionTestUtils;

/// 크레딧 구매·환불 화면이 실제로 그려지는지 (식 하나가 틀리면 그 화면은 500 인데 컴파일로는 안 잡힌다)
class AdminCreditPurchasesTemplateTest {

  private static final LocalDateTime NOW = LocalDateTime.of(2026, 11, 16, 10, 0);

  private final AdminTemplateRenderSupport renderer = new AdminTemplateRenderSupport();

  @Test
  @DisplayName("적립·환불 구매 행, 회수 버튼, 실패한 재확인 기록과 26시간 경고를 그린다")
  void rendersPurchasesWithRecheckWarning() {
    AiCreditPurchase granted = purchase("p-1", "2000000000000001", CreditPurchaseStatus.GRANTED);
    AiCreditPurchase refunded = purchase("p-2", "GPA.1111-2222-3333-44444", CreditPurchaseStatus.REFUNDED);
    refunded.setStore(SubscriptionSource.GOOGLE_IAP);
    refunded.setRefundedAt(NOW);
    refunded.setRecoveredCredits(120);
    refunded.setRefundOrigin(StoreRefundOrigin.REFUND_RECHECK);
    StoreRefundCheckRun failedRun = StoreRefundCheckRun.start(SubscriptionSource.APPLE_IAP, StoreRefundCheckTrigger.ADMIN, "admin", NOW);
    failedRun.recordFailure(StoreRefundCheckFailureReason.CREDENTIALS_NOT_CONFIGURED);

    Map<String, Object> variables = new HashMap<>();
    variables.put("rows", new PageImpl<>(List.of(
      new AdminCreditPurchaseRow(granted, "하늘이 보호자"), new AdminCreditPurchaseRow(refunded, null))));
    variables.put("query", AdminListQuery.of(null, Map.of(), null, null, AdminCreditPurchaseList.DEFINITION));
    variables.put("definition", AdminCreditPurchaseList.DEFINITION);
    variables.put("storeOptions", AdminCreditPurchaseList.STORE_OPTIONS);
    variables.put("statusOptions", AdminCreditPurchaseList.STATUS_OPTIONS);
    variables.put("pagerBaseUrl", "/admin/credits/purchases?sort=createdAt,desc");
    variables.put("recheck", new RecheckOverview(true, List.of(failedRun), List.of(SubscriptionSource.APPLE_IAP)));
    String html = renderer.render("admin/credits-purchases", variables);

    assertThat(html).contains("2000000000000001", "환불 재확인", "회수 120", "스토어 API 키 없음", "data-refund-recheck-attention",
      "/admin/credits/purchases/p-1/revoke");
    assertThat(html).doesNotContain("/admin/credits/purchases/p-2/revoke");
  }

  private static AiCreditPurchase purchase(String id, String transactionId, CreditPurchaseStatus status) {
    AiCreditPurchase purchase = new AiCreditPurchase();
    purchase.setId(id);
    purchase.setStore(SubscriptionSource.APPLE_IAP);
    purchase.setTransactionId(transactionId);
    purchase.setAccountId("acc-" + id);
    purchase.setMemberId("member-" + id);
    purchase.setProductId("elum_credit_150");
    purchase.setCredits(150);
    purchase.setStatus(status);
    ReflectionTestUtils.setField(purchase, "createdAt", NOW.minusDays(1));
    return purchase;
  }
}
