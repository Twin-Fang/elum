package com.chuseok22.elumserver.admin.application.analytics;

/**
 * 가입 뒤 24시간 안에 한 일 4묶음 (#1471, AdminUsageAnalyticsQueries 의 activation_kind 와 같은 이름, 위에서부터 먼저 맞는 하나)
 * 기기 연결 > 카드 체크(기기 연결 없이 한 기기에서 쓴 경우 포함) > 일과만 만듦 > 아무것도 안 함
 */
public enum AdminFirstDayActivationKind {
  DEVICE_LINKED("이룸이 기기 연결"),
  CARD_CHECKED("이룸이 카드 체크"),
  ROUTINE_MADE("일과만 만듦"),
  NOTHING("아무것도 안 함"),
  ;

  private final String label;

  AdminFirstDayActivationKind(String label) {
    this.label = label;
  }

  public String label() {
    return label;
  }
}
