package com.chuseok22.elumserver.credit.core;

/** 크레딧을 쓰는 생성 작업의 종류 (#407). 종류마다 예약량·청구 산식이 다르다. */
public enum CreditJobKind {

  /// AI 일과 생성 — 글 1 + 붙은 그림 수만큼 청구한다.
  ROUTINE_CREATE(true),
  /// 수동 카드 한 장의 그림.
  CARD_IMAGE(false),
  /// 그림 다시 만들기. 엔드포인트는 아직 없다(범위 밖) — 단가 키만 맞춰 둔다.
  IMAGE_REGENERATE(false);

  private final boolean overageAllowed;

  CreditJobKind(boolean overageAllowed) {
    this.overageAllowed = overageAllowed;
  }

  /**
   * 정산에서 청구가 잔액을 넘을 때 초과로 남기는가. 일과 생성만 그렇다 — 그림 수는 끝나야 알고, 잔액이 있을 때
   * 시작한 일과는 끝까지 만든다. 그림 한 장은 청구 = 예약이라 원래 초과가 없고, 반환된 뒤 늦게 끝나도
   * 남은 만큼만 차감한다. 작업 행에 따로 저장하지 않고 종류에서 읽는다 — 둘이 어긋날 수 없게.
   */
  public boolean overageAllowed() {
    return overageAllowed;
  }
}
