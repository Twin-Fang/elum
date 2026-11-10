package com.chuseok22.elumserver.credit.core;

import java.util.Arrays;
import java.util.Optional;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 크레딧 지급 주기 단위: 주(WEEK), 달(MONTH)
 * keyMarker = 주기 키 가운데 글자 (2026-W39, 2026-M11 > 단위끼리 키 안 겹침), 이름은 설정 값·periodUnit 응답으로 나가 변경 금지
 */
@Getter
@AllArgsConstructor
public enum CreditPeriodUnit {

  WEEK('W', "주", "주간", "이번 주"),
  MONTH('M', "달", "월간", "이번 달"),
  ;

  private final char keyMarker;
  /// 관리자 화면: "지난 주 · 다음 달" 같은 꼴
  private final String periodNoun;
  /// 관리자 화면: "주간 지급" 같은 꼴
  private final String adjectiveLabel;
  /// 관리자 화면: "이번 주 사용" 같은 꼴
  private final String currentLabel;

  /// 설정 값 > 단위. 비었거나 모르는 값이면 WEEK (기본 동작 유지)
  public static CreditPeriodUnit fromConfigValue(String value) {
    if (value == null) {
      return WEEK;
    }
    return Arrays.stream(values()).filter(unit -> unit.name().equalsIgnoreCase(value.trim())).findFirst().orElse(WEEK);
  }

  /// 주기 키({@code 2026-W39}) > 단위. 모르는 형식이면 비어 있음
  public static Optional<CreditPeriodUnit> fromPeriodKey(String periodKey) {
    if (periodKey == null || periodKey.length() < 6 || periodKey.charAt(4) != '-') {
      return Optional.empty();
    }
    char marker = periodKey.charAt(5);
    return Arrays.stream(values()).filter(unit -> unit.keyMarker == marker).findFirst();
  }
}
