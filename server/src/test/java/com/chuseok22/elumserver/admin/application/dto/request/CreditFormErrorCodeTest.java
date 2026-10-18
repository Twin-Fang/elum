package com.chuseok22.elumserver.admin.application.dto.request;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 관리자 크레딧 폼이 잘못된 입력을 ADMIN_CREDIT_* 코드로 거절하는지 본다 (화면이 코드를 실어 보여 주는 근거).
class CreditFormErrorCodeTest {

  private static void assertCode(Runnable call, ErrorCode expected) {
    assertThatThrownBy(call::run).isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode()).isEqualTo(expected);
  }

  private static CreditAdjustForm adjust(String type, String amount) {
    return new CreditAdjustForm(type, amount, "NONE", "", "사유");
  }

  private static CreditPolicyForm policy(String freeGrant, String ttl, String reason) {
    return new CreditPolicyForm(freeGrant, "100", "1", "1", "1", ttl, "true", "NEXT_PERIOD", reason);
  }

  @Test
  @DisplayName("조정 폼 — 종류가 비면 TYPE_REQUIRED, 모르는 값이면 TYPE_UNKNOWN(입력값을 detail 로)")
  void adjustType() {
    assertCode(() -> adjust(" ", "1").parsedType(), ErrorCode.ADMIN_CREDIT_ADJUST_TYPE_REQUIRED);
    assertCode(() -> adjust("BOGUS", "1").parsedType(), ErrorCode.ADMIN_CREDIT_ADJUST_TYPE_UNKNOWN);
    assertThatThrownBy(() -> adjust("BOGUS", "1").parsedType())
      .extracting(e -> ((CustomException) e).getDetail()).isEqualTo("BOGUS");
  }

  @Test
  @DisplayName("조정 폼 — 수량이 비면 AMOUNT_REQUIRED, 글자면 AMOUNT_NOT_NUMBER, 동결은 수량을 보지 않는다")
  void adjustAmount() {
    assertCode(() -> adjust("GRANT", "").parsedAmount(), ErrorCode.ADMIN_CREDIT_AMOUNT_REQUIRED);
    assertCode(() -> adjust("GRANT", "삼십").parsedAmount(), ErrorCode.ADMIN_CREDIT_AMOUNT_NOT_NUMBER);
    assertThat(adjust("FREEZE", "").parsedAmount()).isZero();
  }

  @Test
  @DisplayName("정책 폼 — 빈 칸·글자는 라벨을 detail 로 싣고, 사유·TTL·음수는 각자 코드로 거절한다")
  void policyValues() {
    assertCode(() -> policy("", "15", "사유").toDraft(), ErrorCode.ADMIN_CREDIT_POLICY_VALUE_REQUIRED);
    assertThatThrownBy(() -> policy("백", "15", "사유").toDraft())
      .isInstanceOf(CustomException.class)
      .satisfies(e -> {
        assertThat(((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.ADMIN_CREDIT_POLICY_VALUE_NOT_NUMBER);
        assertThat(((CustomException) e).getDetail()).isEqualTo("Free 주간 지급량");
      });
    assertCode(() -> policy("100", "15", " ").toDraft(), ErrorCode.ADMIN_CREDIT_REASON_REQUIRED);
    assertCode(() -> policy("100", "0", "사유").toDraft(), ErrorCode.ADMIN_CREDIT_POLICY_TTL_TOO_SHORT);
    assertCode(() -> policy("-1", "15", "사유").toDraft(), ErrorCode.ADMIN_CREDIT_POLICY_VALUE_NEGATIVE);
  }
}
