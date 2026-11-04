package com.chuseok22.elumserver.license.application.service;

import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;

/**
 * 앱 "내 요금제" 표시용 구독 상태: 등급, 출처, 상품, 만료일, 자동 갱신, 결제 유예
 */
@Schema(description = "지금 요금제 상태. 기존 클라이언트는 이 필드를 무시하므로 동작에 영향이 없다 (#1071)")
public record MemberSubscriptionStatus(

  @Schema(description = "지금 실제로 적용되는 요금제", example = "PRO")
  PlanType plan,

  @Schema(description = "요금제가 생긴 경로. SIGNUP(가입 기본) · MANUAL(관리자 발급) · APPLE_IAP · GOOGLE_IAP · PROMO",
    example = "APPLE_IAP")
  SubscriptionSource source,

  @Schema(description = "스토어 구독 상품 ID. 스토어 결제가 아니면 null", example = "elum_pro_monthly")
  String productId,

  @Schema(description = "Pro 가 끝나는 시각 (KST, 결제 유예 포함). Free 이거나 기간 제한이 없으면 null",
    example = "2026-12-05T10:00:00")
  LocalDateTime expiresAt,

  @Schema(description = "다음 결제일에 자동으로 갱신되는가. 스토어 결제가 아니거나 모르면 null", example = "true")
  Boolean willAutoRenew,

  @Schema(description = "결제가 실패해 스토어가 주는 유예 기간 중인가 (결제 수단 확인 안내용)", example = "false")
  boolean isInGracePeriod
) {

  /// 조회 실패·구독 없음: Free, 가입 기본
  public static MemberSubscriptionStatus free() {
    return new MemberSubscriptionStatus(PlanType.FREE, SubscriptionSource.SIGNUP, null, null, null, false);
  }
}
