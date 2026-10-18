package com.chuseok22.elumserver.admin.application.dto.request;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.service.PolicyDraft;
import com.chuseok22.elumserver.credit.core.CreditAction;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.license.core.PlanType;
import java.util.EnumMap;
import java.util.Map;

/**
 * 관리자 크레딧 정책 발행 폼. 미리보기·확정이 같은 값을 주고받는다.
 *
 * <p>숫자도 문자열로 받는다 — 글자가 오면 바인딩 400 대신 폼 오류로 보이게 {@link #toDraft()} 가 해석한다.
 *
 * @param enabled 체크박스 — 켜져 있으면 "true", 꺼져 있으면 폼에 오지 않아 null
 */
public record CreditPolicyForm(
  String freeGrant,
  String proGrant,
  String costRoutineText,
  String costCardImage,
  String costImageRegenerate,
  String ttlMinutes,
  String enabled,
  String grantApply,
  String reason
) {

  /// 지금 정책 값으로 채운 폼. 사유는 비운다 — 새 사유를 적게 한다.
  public static CreditPolicyForm of(AiCreditPolicy policy) {
    return new CreditPolicyForm(
      String.valueOf(policy.weeklyGrantFor(PlanType.FREE)),
      String.valueOf(policy.weeklyGrantFor(PlanType.PRO)),
      String.valueOf(policy.costOf(CreditAction.ROUTINE_TEXT)),
      String.valueOf(policy.costOf(CreditAction.CARD_IMAGE)),
      String.valueOf(policy.costOf(CreditAction.IMAGE_REGENERATE)),
      String.valueOf(policy.getReservationTtlMinutes()),
      String.valueOf(policy.isEnabled()),
      AiCreditPolicy.GRANT_APPLY_NEXT_PERIOD,
      ""
    );
  }

  public boolean isEnabled() {
    return "true".equalsIgnoreCase(enabled) || "on".equalsIgnoreCase(enabled);
  }

  /**
   * 발행할 정책으로 바꾼다. 음수·사유·적용 시점 검사는 {@code CreditPolicyService.publish} 가 한 번 더 한다.
   *
   * @throws CustomException 빈 칸·숫자가 아닌 값·사유·TTL·음수 (ADMIN_CREDIT_POLICY_* · ADMIN_CREDIT_REASON_REQUIRED)
   */
  public PolicyDraft toDraft() {
    Map<PlanType, Integer> grants = new EnumMap<>(PlanType.class);
    grants.put(PlanType.FREE, number(freeGrant, "Free 주간 지급량"));
    grants.put(PlanType.PRO, number(proGrant, "Pro 주간 지급량"));
    Map<CreditAction, Integer> costs = new EnumMap<>(CreditAction.class);
    costs.put(CreditAction.ROUTINE_TEXT, number(costRoutineText, "일과 글 단가"));
    costs.put(CreditAction.CARD_IMAGE, number(costCardImage, "카드 그림 단가"));
    costs.put(CreditAction.IMAGE_REGENERATE, number(costImageRegenerate, "그림 다시 만들기 단가"));
    int ttl = number(ttlMinutes, "예약 유지 시간");
    String apply = grantApply == null || grantApply.isBlank()
      ? AiCreditPolicy.GRANT_APPLY_NEXT_PERIOD : grantApply.trim();
    String cleanReason = reason == null ? null : reason.trim();
    if (cleanReason == null || cleanReason.isEmpty()) {
      throw new CustomException(ErrorCode.ADMIN_CREDIT_REASON_REQUIRED);
    }
    if (ttl < 1) {
      throw new CustomException(ErrorCode.ADMIN_CREDIT_POLICY_TTL_TOO_SHORT);
    }
    boolean negative = grants.values().stream().anyMatch(v -> v < 0) || costs.values().stream().anyMatch(v -> v < 0);
    if (negative) {
      throw new CustomException(ErrorCode.ADMIN_CREDIT_POLICY_VALUE_NEGATIVE);
    }
    return new PolicyDraft(isEnabled(), grants, costs, ttl, apply, cleanReason);
  }

  private static int number(String raw, String label) {
    if (raw == null || raw.isBlank()) {
      throw new CustomException(ErrorCode.ADMIN_CREDIT_POLICY_VALUE_REQUIRED, label);
    }
    try {
      return Integer.parseInt(raw.trim());
    } catch (NumberFormatException e) {
      throw new CustomException(ErrorCode.ADMIN_CREDIT_POLICY_VALUE_NOT_NUMBER, label);
    }
  }
}
