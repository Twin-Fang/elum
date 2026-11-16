package com.chuseok22.elumserver.admin.application.analytics;

/**
 * 최근 활동 종류 5개 (#1436, AdminUsageAnalyticsQueries 의 activity_kind 와 같은 이름) > 화면 문구
 */
public enum AdminRecentActivityKind {
  SIGNUP,
  ROUTINE_CREATED,
  CARD_CHECKED,
  DEVICE_LINKED,
  STORE_PURCHASE,
  ;

  /** 쿼리 값 > 종류 (모르는 값은 null) */
  public static AdminRecentActivityKind fromQueryValueOrNull(String value) {
    for (AdminRecentActivityKind kind : values()) {
      if (kind.name().equals(value)) {
        return kind;
      }
    }
    return null;
  }

  /** 화면 문구 (카드 체크는 묶인 장 수) */
  public String describe(long itemCount) {
    return switch (this) {
      case SIGNUP -> "가입";
      case ROUTINE_CREATED -> "일과 만듦";
      case CARD_CHECKED -> "카드 " + itemCount + "장 체크";
      case DEVICE_LINKED -> "기기 연결";
      case STORE_PURCHASE -> "스토어 구매";
    };
  }
}
