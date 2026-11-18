package com.chuseok22.elumserver.credit.application.service.purchase;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.credit.application.service.purchase.CreditPackHealthCheck.Finding;
import com.chuseok22.elumserver.credit.application.service.purchase.CreditPackHealthCheck.Snapshot;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 위험한 꾸러미 설정을 점검이 놓치면 관리자는 판매가 깨진 줄 모르고 지나간다
class CreditPackHealthCheckTest {

  private static final String GOOD_PRODUCTS = "elum_credit_50:50,elum_credit_100:100,elum_credit_150:150";

  @Test
  @DisplayName("설정이 모두 정상이면 정상 한 줄만 낸다")
  void reportsOkWhenNothingIsWrong() {
    List<Finding> findings = CreditPackHealthCheck.check(snapshot(false, true, true, GOOD_PRODUCTS, "elum_credit_100", true));

    assertThat(findings).hasSize(1);
    assertThat(findings.get(0).isWarning()).isFalse();
  }

  @Test
  @DisplayName("판매가 켜졌는데 상품이 하나도 없으면 경고한다")
  void warnsWhenSellingWithoutProducts() {
    List<Finding> findings = CreditPackHealthCheck.check(snapshot(false, true, false, "", "", true));

    assertThat(findings).anyMatch(finding -> finding.isWarning() && finding.message().contains("상품이 하나도 없어요"));
  }

  @Test
  @DisplayName("인기 상품이 목록에 없으면 경고한다")
  void warnsWhenPopularProductIsMissingFromList() {
    List<Finding> findings = CreditPackHealthCheck.check(snapshot(false, true, true, GOOD_PRODUCTS, "elum_credit_400", true));

    assertThat(findings).anyMatch(finding -> finding.isWarning() && finding.message().contains("elum_credit_400"));
  }

  @Test
  @DisplayName("같은 상품 ID 가 두 번이면 중복만 경고하고 형식 경고는 겹쳐 내지 않는다")
  void warnsDuplicateProductIdOnly() {
    List<Finding> findings = CreditPackHealthCheck.check(snapshot(false, true, true, "elum_credit_50:50,elum_credit_50:60", "", true));

    assertThat(findings).hasSize(1);
    assertThat(findings.get(0).message()).contains("두 번 있어요");
  }

  @Test
  @DisplayName("형식이 틀린 항목은 건너뛰는 개수를 알려 준다")
  void warnsSkippedMalformedItems() {
    List<Finding> findings = CreditPackHealthCheck.check(snapshot(false, true, true, "elum_credit_50:50,oops", "", true));

    assertThat(findings).anyMatch(finding -> finding.message().contains("건너뛰는 항목이 있어요 (1개)"));
  }

  @Test
  @DisplayName("전체 스위치가 켜져 있으면 스토어 스위치를 우회하는 것을 경고한다")
  void warnsWhenAllSwitchIsOn() {
    List<Finding> findings = CreditPackHealthCheck.check(snapshot(true, false, false, GOOD_PRODUCTS, "", true));

    assertThat(findings).anyMatch(finding -> finding.message().contains("전체 판매 스위치가 켜져 있어요"));
  }

  @Test
  @DisplayName("판매 중인데 환불 재확인이 꺼져 있으면 경고하고, 판매가 모두 꺼졌으면 경고하지 않는다")
  void warnsRefundRecheckOffOnlyWhileSelling() {
    assertThat(CreditPackHealthCheck.check(snapshot(false, true, false, GOOD_PRODUCTS, "", false)))
      .anyMatch(finding -> finding.message().contains("환불 재확인이 꺼져 있어요"));
    assertThat(CreditPackHealthCheck.check(snapshot(false, false, false, GOOD_PRODUCTS, "", false)))
      .noneMatch(finding -> finding.message().contains("환불 재확인"));
  }

  private static Snapshot snapshot(
    boolean isAll, boolean isApple, boolean isGoogle, String products, String popular, boolean isRecheckEnabled
  ) {
    return new Snapshot(isAll, isApple, isGoogle, products, popular, isRecheckEnabled);
  }
}
