package com.chuseok22.elumserver.systemconfig.core;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigValueValidator;
import com.chuseok22.elumserver.systemconfig.core.CreditPackListFormat.Pack;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 꾸러미 설정 형식: 오타가 저장되면 상품이 조용히 사라지거나 개수가 틀리게 적립된다
class CreditPackListFormatTest {

  @Test
  @DisplayName("기본값은 3개 꾸러미(50·150·400)로 읽히고 저장 검사도 통과한다")
  void defaultValue_parsesAndPassesValidation() {
    String defaultValue = ConfigKey.CREDIT_PACK_PRODUCTS.getDefaultValue();

    assertThat(CreditPackListFormat.parse(defaultValue)).containsExactly(
      new Pack("elum_credit_50", 50), new Pack("elum_credit_150", 150), new Pack("elum_credit_400", 400));
    assertThat(SystemConfigValueValidator.check(ConfigKey.CREDIT_PACK_PRODUCTS, defaultValue).isValid()).isTrue();
  }

  @Test
  @DisplayName("형식이 틀린 항목·0개·중복 상품은 저장을 거부한다")
  void invalidItems_areRejectedOnSave() {
    for (String bad : List.of("elum_credit_50", "elum_credit_50:abc", "elum_credit_50:0", "a:1,a:2", ":5", "x y:5")) {
      assertThat(SystemConfigValueValidator.check(ConfigKey.CREDIT_PACK_PRODUCTS, bad).isValid()).as(bad).isFalse();
    }
  }

  @Test
  @DisplayName("읽을 때는 틀린 항목만 건너뛴다 — 한 항목의 오타가 다른 꾸러미 판매까지 막지 않는다")
  void parse_skipsBadItems() {
    assertThat(CreditPackListFormat.parse("elum_credit_50:50, broken ,elum_credit_50:60,elum_credit_150:150"))
      .containsExactly(new Pack("elum_credit_50", 50), new Pack("elum_credit_150", 150));
  }
}
