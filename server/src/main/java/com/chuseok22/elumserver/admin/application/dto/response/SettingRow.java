package com.chuseok22.elumserver.admin.application.dto.response;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * 설정 표 한 행: 이름·키, 현재 값, 기본값, 마지막 변경(시각·변경자·사유)
 * 비밀값은 currentValue 가 항상 빈 값이고 displayValue 만 "설정됨"/"설정 안 됨"
 */
public record SettingRow(
  String key,
  String label,
  String description,
  String groupName,
  String groupLabel,
  String valueType,
  List<String> allowedValues,
  Integer minValue,
  Integer maxValue,
  /** 입력칸에 넣을 현재 값 (비밀값은 빈 값) */
  String currentValue,
  /** 표에 보일 현재 값 (불리언 켜짐/꺼짐, 비밀값 설정됨) */
  String displayValue,
  /** 입력칸에 넣을 기본값 */
  String defaultValue,
  String defaultDisplayValue,
  /** 유효 기본값(yml 포함)과 다름. 비어서 기본값으로 폴백되면 같음, 비밀값은 항상 false */
  boolean isDifferent,
  boolean isSecret,
  boolean hasHistory,
  LocalDateTime lastChangedAt,
  String lastChangedBy,
  String lastReason
) {

  /** 입력 위젯 구분: 불리언은 토글, 날짜시간은 날짜 선택기 */
  public boolean isBoolean() {
    return "BOOLEAN".equals(valueType);
  }

  public boolean isDatetime() {
    return "DATETIME".equals(valueType);
  }

  /** 마지막 변경이 그날인지 ("오늘 변경" 칩) */
  public boolean isChangedOn(LocalDate day) {
    return lastChangedAt != null && lastChangedAt.toLocalDate().equals(day);
  }

  /** 검색 대상: 이름·키·값·설명·그룹·변경자 (소문자). 비밀값은 값을 넣지 않음 */
  public String searchText() {
    return Stream.of(label, key, displayValue, description, groupLabel, lastChangedBy)
      .filter(text -> text != null && !text.isBlank())
      .collect(Collectors.joining(" "))
      .toLowerCase(Locale.ROOT);
  }
}
