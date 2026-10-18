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
    if (q == null) {
      return null;
    }
    String escaped = q.replace(LIKE_ESCAPE, LIKE_ESCAPE + LIKE_ESCAPE)
      .replace("%", LIKE_ESCAPE + "%")
      .replace("_", LIKE_ESCAPE + "_");
    return "%" + escaped + "%";
  }

  /** 현재 검색·필터를 유지한 "?q=..&필터=..&sort=..&page=.." (page 1 은 생략, 값은 URL 인코딩) */
  public String toQueryString(String sortToUse, int pageToUse) {
    StringBuilder builder = new StringBuilder();
    appendParam(builder, "q", q);
    filters.forEach((key, value) -> appendParam(builder, key, value));
    appendParam(builder, "sort", sortToUse);
    if (pageToUse > 1) {
      appendParam(builder, "page", String.valueOf(pageToUse));
    }
    return builder.toString();
  }

  private static void appendParam(StringBuilder builder, String key, String value) {
    if (value == null) {
      return;
    }
    builder.append(builder.length() == 0 ? '?' : '&').append(key).append('=');
    // 정렬 값의 콤마는 읽기 쉽게 그대로 둔다
    builder.append(UriUtils.encodeQueryParam(value, StandardCharsets.UTF_8).replace("%2C", ","));
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
