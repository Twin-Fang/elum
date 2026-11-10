package com.chuseok22.elumserver.credit.core;

import java.util.Map;

/**
 * 크레딧 요약의 종류별 줄. 이름은 앱이 읽는 값이라 바꾸지 않는다.
 * 순서가 화면 순서: 이번 주기 지급, 보너스(관리자·광고·이벤트), 구매
 */
public enum CreditBreakdownKind {
  PERIODIC,
  BONUS,
  PURCHASED;

  private static final Map<CreditGrantSource, CreditBreakdownKind> KIND_BY_SOURCE = Map.of(
    CreditGrantSource.WEEKLY, PERIODIC,
    CreditGrantSource.ADMIN_BONUS, BONUS,
    CreditGrantSource.AD_REWARD, BONUS,
    CreditGrantSource.PROMO, BONUS,
    CreditGrantSource.PURCHASE, PURCHASED
  );

  /// 적립 출처 > 종류 (WEEKLY 는 주기 단위가 달이어도 PERIODIC)
  public static CreditBreakdownKind of(CreditGrantSource source) {
    return KIND_BY_SOURCE.get(source);
  }
}
