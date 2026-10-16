package com.chuseok22.elumserver.credit.core;

/**
 * 보호자에게 보이는 크레딧 내역 한 줄의 종류. 원장 줄의 내부 사유 글은 노출하지 않고 이 종류로만 말한다.
 *
 * <p>앱이 종류별 문구를 정한다. 모르는 종류가 오면 앱은 증감 부호로 일반 문구를 쓴다.
 */
public enum CreditHistoryKind {

  /// AI 일과 글 만들기 (사용)
  ROUTINE_TEXT,
  /// 일과와 함께 만든 카드 그림 (사용)
  CARD_IMAGES,
  /// 카드 한 장의 그림 직접 만들기 (사용)
  CARD_IMAGE,
  /// 그림 다시 만들기 (사용)
  IMAGE_REGENERATE,
  /// 이번 주 크레딧 채움 (지급)
  WEEKLY_GRANT,
  /// 보상형 광고를 보고 받음 (지급)
  AD_REWARD,
  /// 운영에서 준 보너스 (지급)
  ADMIN_BONUS,
  /// 그 밖의 지급
  OTHER_GRANT,
  /// 지난 크레딧이 사라짐 (만료)
  EXPIRED,
  /// 운영이 바로잡음 (증감 모두)
  ADJUSTED
}
