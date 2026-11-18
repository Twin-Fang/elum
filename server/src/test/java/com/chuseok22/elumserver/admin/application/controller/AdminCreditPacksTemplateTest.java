package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.ActivitySection;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.DraftRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.HistoryRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.ProductRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.ProductsSection;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.SaleSection;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.StoreSale;
import com.chuseok22.elumserver.credit.application.service.purchase.CreditPackHealthCheck.Finding;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 꾸러미 화면이 실제로 그려지는지 (식 하나가 틀리면 그 화면은 500 인데 컴파일로는 안 잡힌다)
class AdminCreditPacksTemplateTest {

  private final AdminTemplateRenderSupport renderer = new AdminTemplateRenderSupport();

  @Test
  @DisplayName("판매 현황, 점검 경고, 상품 줄, 미리보기, 이력을 그리고 판매 중 스토어는 끄기 버튼을 낸다")
  void rendersFullScreen() {
    List<ProductRow> rows = List.of(new ProductRow("elum_credit_50", 50, false), new ProductRow("elum_credit_100", 100, true));
    AdminCreditPackView view = new AdminCreditPackView(
      new SaleSection(false, List.of(
        new StoreSale(SubscriptionSource.APPLE_IAP, "App Store 결제", true),
        new StoreSale(SubscriptionSource.GOOGLE_IAP, "Google Play 결제", false))),
      new ProductsSection(rows, "elum_credit_100"),
      List.of(new Finding(true, "환불 재확인이 꺼져 있어요")),
      new ActivitySection(0, 0),
      List.of(new HistoryRow("크레딧 꾸러미 판매 (App Store)", "false", "true", "kimchi", "심사 통과", LocalDateTime.of(2026, 11, 16, 8, 30))),
      List.of());

    Map<String, Object> variables = new HashMap<>();
    variables.put("view", view);
    variables.put("draftRows", List.of(new DraftRow("elum_credit_50", "50")));
    variables.put("popularProductId", "elum_credit_100");
    variables.put("previewRows", rows);
    variables.put("isPreviewShown", true);
    String html = renderer.render("admin/credits-packs", variables);

    assertThat(html).contains("판매 중", "환불 재확인이 꺼져 있어요", "elum_credit_50", "data-pack-preview", "인기!", "심사 통과",
      "/admin/credits/packs/sale", "/admin/credits/packs/save", "/admin/credits/packs/preview");
  }

  @Test
  @DisplayName("일부 칸을 읽지 못해도 나머지 칸과 오류 코드를 그린다")
  void rendersWhenSectionsFailed() {
    AdminCreditPackView view = new AdminCreditPackView(null, null, null, null, null, List.of("E-ADMIN-CREDIT-PACKS-SALE"));

    Map<String, Object> variables = new HashMap<>();
    variables.put("view", view);
    variables.put("draftRows", List.of(new DraftRow("", "")));
    variables.put("popularProductId", "");
    variables.put("previewRows", List.of());
    variables.put("isPreviewShown", false);
    String html = renderer.render("admin/credits-packs", variables);

    assertThat(html).contains("E-ADMIN-CREDIT-PACKS-SALE", "꾸러미 상품");
  }
}
