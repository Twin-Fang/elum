package com.chuseok22.elumserver.credit.core;

/**
 * 적립 묶음이 어디서 왔는가 (#407).
 *
 * <p>PROMO·PURCHASE 는 아직 쓰지 않는다. 결제·이벤트를 붙일 때 표를 바꾸지 않으려고 자리만 둔다.
 */
public enum CreditGrantSource {

  /// 매주 월요일 0시 주기로 한 번 지급. 주기가 끝나면 남은 양은 만료된다(이월 없음).
  WEEKLY,
  /// 관리자가 손으로 준 보너스. 만료는 지급 때 고른다(기본 이번 주 말, 무기한 가능).
  ADMIN_BONUS,
  PROMO,
  PURCHASE,
}
