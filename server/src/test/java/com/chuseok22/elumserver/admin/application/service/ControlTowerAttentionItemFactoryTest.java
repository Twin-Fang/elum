package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.AdminDashboardAttention;
import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerAttentionItem;
import com.chuseok22.elumserver.admin.application.dto.response.ControlTowerAttentionLevel;
import com.chuseok22.elumserver.ai.application.dto.response.AiHealthSnapshot;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

/// 관제소 항목 규칙: 오늘 AI 비용 gauge 수준(상한 80% warning, 100% critical), 상한 꺼짐 limit 생략, 상대 관리자 경로
class ControlTowerAttentionItemFactoryTest {

  private static AdminDashboardAttention attentionWithBudget(double budgetUsd, double spentUsd) {
    return new AdminDashboardAttention(0, 0, 0, new AiHealthSnapshot(List.of(), List.of()), budgetUsd, spentUsd);
  }

  private static ControlTowerAttentionItem budgetItemOf(AdminDashboardAttention attention, String adminBaseUrl) {
    return ControlTowerAttentionItemFactory.itemsOf(attention, 0, adminBaseUrl).stream()
      .filter(item -> item.key().equals(ControlTowerAttentionItemFactory.KEY_BUDGET_DAILY))
      .findFirst().orElseThrow();
  }

  @ParameterizedTest(name = "상한 {0} USD, 사용 {1} USD > {2}")
  @CsvSource({
    "10, 0, OK",
    "10, 7.9, OK",
    "10, 8, WARNING",
    "10, 9.99, CRITICAL",
    "10, 10, CRITICAL",
    "10, 25, CRITICAL",
    "0, 0, CRITICAL"
  })
  @DisplayName("상한이 켜져 있으면 사용률로 수준 결정 (대시보드와 같은 반올림, 상한 0 은 100%)")
  void budgetEnabled_levelByUsedPercent(double budgetUsd, double spentUsd, ControlTowerAttentionLevel expectedLevel) {
    ControlTowerAttentionItem item = budgetItemOf(attentionWithBudget(budgetUsd, spentUsd), "");

    assertThat(item.level()).isEqualTo(expectedLevel);
    assertThat(item.limit()).isEqualTo(budgetUsd);
    assertThat(item.value()).isEqualTo(spentUsd);
    assertThat(item.unit()).isEqualTo("USD");
    assertThat(item.kind()).isEqualTo("gauge");
  }

  @Test
  @DisplayName("상한이 꺼져 있으면(-1) 비용이 커도 ok 이고 limit 이 없다")
  void budgetDisabled_okWithoutLimit() {
    ControlTowerAttentionItem item = budgetItemOf(attentionWithBudget(-1, 999), "");

    assertThat(item.level()).isEqualTo(ControlTowerAttentionLevel.OK);
    assertThat(item.limit()).isNull();
    assertThat(item.value()).isEqualTo(999);
  }

  @Test
  @DisplayName("기준 주소가 없으면 관리자 경로는 / 로 시작하는 상대 경로")
  void withoutAdminBaseUrl_relativeAdminPaths() {
    List<ControlTowerAttentionItem> items =
      ControlTowerAttentionItemFactory.itemsOf(attentionWithBudget(-1, 0), 0, "");

    assertThat(items).extracting(ControlTowerAttentionItem::adminUrl).allMatch(adminUrl -> adminUrl.startsWith("/admin/"));
    assertThat(items).extracting(ControlTowerAttentionItem::label).allMatch(label -> !label.isBlank() && label.length() <= 40);
  }
}
