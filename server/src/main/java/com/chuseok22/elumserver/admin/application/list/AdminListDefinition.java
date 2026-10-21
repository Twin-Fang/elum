package com.chuseok22.elumserver.admin.application.list;

import java.util.List;

/**
 * 관리자 목록 선언: 열, 검색 대상, 필터, 기본 정렬
 * 화면은 정의 하나로 표·필터 바·정렬을 같은 방식으로 얻고, 쿼리 보정(AdminListQuery)도 이 정의를 기준으로 한다
 */
public record AdminListDefinition(
  List<Column> columns,
  List<String> searchFields,
  List<Filter> filters,
  String defaultSort
) {

  /** 정렬 문자열 "열키,방향" 구분자 */
  public static final String SORT_DELIMITER = ",";
  public static final String SORT_ASCENDING = "asc";
  public static final String SORT_DESCENDING = "desc";

  /** 표의 열: isSortable 인 열만 정렬 허용 목록에 든다, isNumeric 이면 표에서 우측 정렬 */
  public record Column(String key, String label, boolean isSortable, boolean isNumeric) {

    public Column(String key, String label, boolean isSortable) {
      this(key, label, isSortable, false);
    }

    /// 숫자 열 (건수·토큰·금액·크레딧, 우측 정렬)
    public static Column numeric(String key, String label, boolean isSortable) {
      return new Column(key, label, isSortable, true);
    }
  }

  /**
   * 필터: options 가 있으면 칩, 비어 있으면 값 제한 없는 자유 입력 필터
   * inputType 이 TEXT·DATE 면 필터 바가 입력 칸을 그림 (NONE 은 화면이 직접 그리거나 숨은 값으로만 유지)
   */
  public record Filter(String key, String label, List<Option> options, InputType inputType) {

    public Filter {
      options = options == null ? List.of() : List.copyOf(options);
      inputType = inputType == null ? InputType.NONE : inputType;
    }

    public Filter(String key, String label, List<Option> options) {
      this(key, label, options, InputType.NONE);
    }

    /// 날짜 입력 필터 (yyyy-MM-dd, 형식이 틀리면 보정 단계에서 빠짐)
    public static Filter date(String key, String label) {
      return new Filter(key, label, List.of(), InputType.DATE);
    }

    /// 글자 입력 필터 (최대 AdminListQuery.MAX_KEYWORD_LENGTH 자)
    public static Filter text(String key, String label) {
      return new Filter(key, label, List.of(), InputType.TEXT);
    }

    public boolean isAllowedValue(String value) {
      if (inputType == InputType.DATE) {
        return AdminDateParameter.parseOrNull(value) != null;
      }
      return options.isEmpty() || options.stream().anyMatch(option -> option.value().equals(value));
    }

    /// 필터 바가 입력 칸(글자·날짜)을 그리는 필터인가
    public boolean hasInputField() {
      return inputType != InputType.NONE;
    }

    public boolean isDateInput() {
      return inputType == InputType.DATE;
    }

    /// 적용된 값 > 칩에 보일 글 (선택지면 선택지 이름, 아니면 값 그대로)
    public String displayValueOf(String value) {
      return options.stream()
        .filter(option -> option.value().equals(value))
        .map(Option::label)
        .findFirst()
        .orElse(value);
    }
  }

  /// 필터 입력 방식: NONE 칩·숨은 값, TEXT 글자 칸, DATE 날짜 칸
  public enum InputType {
    NONE, TEXT, DATE
  }

  public record Option(String value, String label) {
  }

  public AdminListDefinition {
    columns = columns == null ? List.of() : List.copyOf(columns);
    searchFields = searchFields == null ? List.of() : List.copyOf(searchFields);
    filters = filters == null ? List.of() : List.copyOf(filters);
    // 기본 정렬이 허용 밖이면 정의를 만드는 시점에 바로 드러낸다
    if (!isValidSort(columns, defaultSort)) {
      throw new IllegalArgumentException("defaultSort must be a sortable column: " + defaultSort);
    }
  }

  /// 키 > 필터 (없으면 null: 화면이 적용된 필터 칩 이름을 찾을 때)
  public Filter filterOf(String key) {
    return filters.stream().filter(filter -> filter.key().equals(key)).findFirst().orElse(null);
  }

  public boolean isValidSort(String sort) {
    return isValidSort(columns, sort);
  }

  private static boolean isValidSort(List<Column> columns, String sort) {
    if (sort == null) {
      return false;
    }
    String[] parts = sort.split(SORT_DELIMITER, -1);
    if (parts.length > 2) {
      return false;
    }
    if (parts.length == 2 && !SORT_ASCENDING.equals(parts[1]) && !SORT_DESCENDING.equals(parts[1])) {
      return false;
    }
    return columns.stream().anyMatch(column -> column.isSortable() && column.key().equals(parts[0]));
  }
}
