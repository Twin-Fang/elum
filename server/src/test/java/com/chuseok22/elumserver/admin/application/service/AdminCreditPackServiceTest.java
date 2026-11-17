package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.DraftRow;
import com.chuseok22.elumserver.admin.application.service.AdminCreditPackService.DraftCheck;
import com.chuseok22.elumserver.admin.application.service.AdminCreditPackService.SaleChange;
import com.chuseok22.elumserver.credit.application.service.purchase.CreditPurchaseAdminQueryService;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigHistoryService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.core.CreditPackListFormat;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 꾸러미 편집이 잘못 저장돼 판매 목록이 깨지거나, 사유 없이 판매가 바뀌는 것을 막는다
class AdminCreditPackServiceTest {

  private final SystemConfigService config = mock(SystemConfigService.class);
  private final AdminCreditPackService service = new AdminCreditPackService(
    config, mock(SystemConfigHistoryService.class), mock(CreditPurchaseAdminQueryService.class));

  @Test
  @DisplayName("편집 입력을 직렬화하면 판매 목록 파서가 같은 꾸러미로 읽는다")
  void serializedProductsRoundTripThroughParser() {
    String text = AdminCreditPackService.serialize(List.of(
      new DraftRow(" elum_credit_50 ", "50"), new DraftRow("", ""), new DraftRow("elum_credit_100", " 100")));

    assertThat(text).isEqualTo("elum_credit_50:50,elum_credit_100:100");
    assertThat(CreditPackListFormat.parse(text)).extracting("productId", "credits")
      .containsExactly(org.assertj.core.groups.Tuple.tuple("elum_credit_50", 50), org.assertj.core.groups.Tuple.tuple("elum_credit_100", 100));
  }

  @Test
  @DisplayName("한 칸만 빈 줄은 거절하고 미리보기를 만들지 않는다")
  void rejectsHalfFilledRow() {
    DraftCheck check = service.checkDraft(List.of(new DraftRow("elum_credit_50", "")), "");

    assertThat(check.isValid()).isFalse();
    assertThat(check.previewRows()).isEmpty();
  }

  @Test
  @DisplayName("인기 상품이 목록에 없으면 거절하고, 있으면 미리보기에 인기 표시가 붙는다")
  void checksPopularProductAgainstList() {
    List<DraftRow> rows = List.of(new DraftRow("elum_credit_50", "50"), new DraftRow("elum_credit_100", "100"));

    assertThat(service.checkDraft(rows, "elum_credit_400").isValid()).isFalse();
    DraftCheck ok = service.checkDraft(rows, "elum_credit_100");
    assertThat(ok.isValid()).isTrue();
    assertThat(ok.previewRows()).extracting("isPopular").containsExactly(false, true);
  }

  @Test
  @DisplayName("사유 없이 판매를 바꾸면 설정을 저장하지 않는다")
  void doesNotChangeSaleWithoutReason() {
    SaleChange result = service.setStoreSale(SubscriptionSource.GOOGLE_IAP, false, "admin", "  ");

    assertThat(result.isChanged()).isFalse();
    verify(config, never()).update(any(), any(), any(), any());
  }

  @Test
  @DisplayName("사유가 있으면 그 스토어 스위치만 관리자와 사유를 붙여 바꾼다")
  void changesOnlyThatStoreSwitchWithActorAndReason() {
    SaleChange result = service.setStoreSale(SubscriptionSource.APPLE_IAP, false, "kimchi", "문제 발생");

    assertThat(result.isChanged()).isTrue();
    verify(config).update(ConfigKey.CREDIT_PACK_APPLE_SALE_ENABLED, "false", "kimchi", "문제 발생");
    verify(config, never()).update(eq(ConfigKey.CREDIT_PACK_GOOGLE_SALE_ENABLED), any(), any(), any());
  }

  @Test
  @DisplayName("저장은 상품 목록과 인기 상품을 같은 사유로 함께 저장한다")
  void savesProductsAndPopularTogether() {
    DraftCheck result = service.saveDraft(
      List.of(new DraftRow("elum_credit_50", "50"), new DraftRow("elum_credit_100", "100")), "elum_credit_100", "kimchi", "구성 변경");

    assertThat(result.isValid()).isTrue();
    verify(config).update(ConfigKey.CREDIT_PACK_PRODUCTS, "elum_credit_50:50,elum_credit_100:100", "kimchi", "구성 변경");
    verify(config).update(ConfigKey.CREDIT_PACK_POPULAR_PRODUCT_ID, "elum_credit_100", "kimchi", "구성 변경");
  }
}
