package com.chuseok22.elumserver.admin.application.list;

import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.web.util.UriUtils;

/**
 * 목록 요청 조건: 검색어, 필터, 정렬, 페이지(1부터)
 * of() 가 정의 기준으로 보정(잘못된 정렬·필터는 기본값/제거, 페이지는 1 이상, 빈 검색어는 null)
 */
public record AdminListQuery(String q, Map<String, String> filters, String sort, int page) {

  /** 검색어 최대 길이 */
  public static final int MAX_KEYWORD_LENGTH = 100;
  /// 요청 파라미터 이름: 검색어, 정렬, 페이지 (필터는 정의의 키)
  public static final String PARAMETER_KEYWORD = "q";
  public static final String PARAMETER_SORT = "sort";
  public static final String PARAMETER_PAGE = "page";
  private static final String LIKE_ESCAPE = "\\";

  public AdminListQuery {
    filters = filters == null ? Map.of() : Collections.unmodifiableMap(new LinkedHashMap<>(filters));
  }

  public static AdminListQuery of(
    String q, Map<String, String> filters, String sort, String page, AdminListDefinition definition
  ) {
    String sortOrDefault = sort != null && definition.isValidSort(sort.trim()) ? sort.trim() : definition.defaultSort();
    return new AdminListQuery(normalizeKeyword(q), normalizeFilters(filters, definition), sortOrDefault, parsePage(page));
  }

  /// 요청 파라미터 전체(@RequestParam Map) > 보정된 쿼리. 필터는 정의에 있는 키만 읽음 (새 필터를 더해도 컨트롤러는 그대로)
  public static AdminListQuery fromParameters(Map<String, String> parameters, AdminListDefinition definition) {
    Map<String, String> safeParameters = parameters == null ? Map.of() : parameters;
    return of(safeParameters.get(PARAMETER_KEYWORD), safeParameters, safeParameters.get(PARAMETER_SORT),
      safeParameters.get(PARAMETER_PAGE), definition);
  }

  /** 전체 페이지 수를 안 뒤 범위 밖 페이지를 마지막 페이지로 맞춘다 (결과 0건이면 1) */
  public AdminListQuery withTotalPages(int totalPages) {
    int lastPage = Math.max(totalPages, 1);
    return new AdminListQuery(q, filters, sort, Math.min(page, lastPage));
  }

  /** 필터 하나만 바꾼 쿼리 (value 가 null 이면 그 필터 해제) */
  public AdminListQuery withFilter(String key, String value) {
    Map<String, String> changed = new LinkedHashMap<>(filters);
    if (value == null) {
      changed.remove(key);
    } else {
      changed.put(key, value);
    }
    return new AdminListQuery(q, changed, sort, page);
  }

  /// 검색어만 바꾼 쿼리 (null 이면 검색어 해제)
  public AdminListQuery withKeyword(String keyword) {
    return new AdminListQuery(normalizeKeyword(keyword), filters, sort, page);
  }

  /// 검색어·필터를 모두 뺀 쿼리 (정렬은 유지, 1페이지): 필터 초기화 링크
  public AdminListQuery withoutConditions() {
    return new AdminListQuery(null, Map.of(), sort, 1);
  }

  /// 검색어나 필터가 하나라도 적용됐는가 (적용된 조건 칩·빈 상태 문구 판단)
  public boolean hasConditions() {
    return q != null || !filters.isEmpty();
  }

  /** Spring Data 용 0부터 시작하는 페이지 번호 */
  public int pageIndex() {
    return page - 1;
  }

  public String sortKey() {
    return sort.split(AdminListDefinition.SORT_DELIMITER, -1)[0];
  }

  /** 방향 생략은 내림차순 (최근 변경순이 기본) */
  public boolean isAscending() {
    return sort.endsWith(AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_ASCENDING);
  }

  /** 열 헤더 클릭 시 정렬: 같은 열이면 방향 뒤집기, 다른 열이면 내림차순으로 시작 */
  public String nextSortFor(String columnKey) {
    boolean isSameColumn = sortKey().equals(columnKey);
    String nextDirection = isSameColumn && !isAscending()
      ? AdminListDefinition.SORT_ASCENDING
      : AdminListDefinition.SORT_DESCENDING;
    return columnKey + AdminListDefinition.SORT_DELIMITER + nextDirection;
  }

  /** LIKE 검색 패턴: %, _, \ 이스케이프 (쿼리에 ESCAPE '\' 필요), 검색어 없으면 null */
  public String likePattern() {
    return toLikePattern(q);
  }

  /// 아무 글자 > 포함 검색 LIKE 패턴 (%, _, \ 이스케이프, 비었으면 null): 필터 값(보호자·모델명 등) 검색용
  public static String toLikePattern(String text) {
    if (text == null || text.isBlank()) {
      return null;
    }
    return "%" + escapeLike(text.trim()) + "%";
  }

  /// 아무 글자 > 앞부분 일치 LIKE 패턴 (앱 버전처럼 "1.0" 으로 1.0.x 를 찾을 때, 비었으면 null)
  public static String toPrefixLikePattern(String text) {
    if (text == null || text.isBlank()) {
      return null;
    }
    return escapeLike(text.trim()) + "%";
  }

  private static String escapeLike(String text) {
    return text.replace(LIKE_ESCAPE, LIKE_ESCAPE + LIKE_ESCAPE)
      .replace("%", LIKE_ESCAPE + "%")
      .replace("_", LIKE_ESCAPE + "_");
  }

  /** 현재 검색·필터를 유지한 "?q=..&필터=..&sort=..&page=.." (page 1 은 생략, 값은 URL 인코딩) */
  public String toQueryString(String sortToUse, int pageToUse) {
    StringBuilder builder = new StringBuilder();
    appendParam(builder, PARAMETER_KEYWORD, q);
    filters.forEach((key, value) -> appendParam(builder, key, value));
    appendParam(builder, PARAMETER_SORT, sortToUse);
    if (pageToUse > 1) {
      appendParam(builder, PARAMETER_PAGE, String.valueOf(pageToUse));
    }
    return builder.toString();
  }

  private static void appendParam(StringBuilder builder, String key, String value) {
    if (value == null) {
      return;
    }
    builder.append(builder.length() == 0 ? '?' : '&').append(key).append('=');
    // 정렬 값의 콤마는 읽기 쉽게 그대로 둔다. + 는 받는 쪽에서 공백으로 읽혀 %2B 로 바꾼다
    builder.append(UriUtils.encodeQueryParam(value, StandardCharsets.UTF_8)
      .replace("%2C", ",").replace("+", "%2B"));
  }

  private static String normalizeKeyword(String raw) {
    if (raw == null || raw.isBlank()) {
      return null;
    }
    String trimmed = raw.trim();
    return trimmed.length() > MAX_KEYWORD_LENGTH ? trimmed.substring(0, MAX_KEYWORD_LENGTH) : trimmed;
  }

  private static Map<String, String> normalizeFilters(Map<String, String> raw, AdminListDefinition definition) {
    Map<String, String> normalized = new LinkedHashMap<>();
    if (raw == null) {
      return normalized;
    }
    for (AdminListDefinition.Filter filter : definition.filters()) {
      String value = raw.get(filter.key());
      if (value == null || value.isBlank()) {
        continue;
      }
      String trimmed = value.trim();
      if (trimmed.length() <= MAX_KEYWORD_LENGTH && filter.isAllowedValue(trimmed)) {
        normalized.put(filter.key(), trimmed);
      }
    }
    return normalized;
  }

  private static int parsePage(String raw) {
    if (raw == null) {
      return 1;
    }
    try {
      return Math.max(Integer.parseInt(raw.trim()), 1);
    } catch (NumberFormatException e) {
      return 1;
    }
  }
}
