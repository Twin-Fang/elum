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

  /** 표의 열: isSortable 인 열만 정렬 허용 목록에 든다 */
  public record Column(String key, String label, boolean isSortable) {
  }

  /** 칩 필터: options 가 비어 있으면 값 제한 없는 자유 입력 필터 */
  public record Filter(String key, String label, List<Option> options) {

    public Filter {
      options = options == null ? List.of() : List.copyOf(options);
    }

    public boolean isAllowedValue(String value) {
      return options.isEmpty() || options.stream().anyMatch(option -> option.value().equals(value));
    }
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
