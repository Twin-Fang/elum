package com.chuseok22.elumserver.admin.application.list;

import java.util.function.Function;
import org.springframework.data.domain.Page;

/**
 * 목록 조회 공통: 조회 > 범위 밖 페이지면 마지막 페이지로 맞춰 다시 조회
 * 결과 0건이면 1페이지 그대로 (재조회 없음)
 */
public final class AdminListPaging {

  private AdminListPaging() {
  }

  public static <T> Page<T> fetchWithPageCorrection(AdminListQuery query, Function<AdminListQuery, Page<T>> fetcher) {
    Page<T> page = fetcher.apply(query);
    if (page.getTotalPages() > 0 && query.page() > page.getTotalPages()) {
      return fetcher.apply(query.withTotalPages(page.getTotalPages()));
    }
    return page;
  }
}
