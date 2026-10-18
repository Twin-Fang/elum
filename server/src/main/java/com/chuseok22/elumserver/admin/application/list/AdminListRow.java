package com.chuseok22.elumserver.admin.application.list;

import java.util.Map;

/**
 * 공통 표의 한 행: 열 키별 표시 문자열, 첫 칸에 걸 링크(없으면 null)
 */
public record AdminListRow(String linkUrl, Map<String, String> cells) {

  public AdminListRow {
    cells = cells == null ? Map.of() : Map.copyOf(cells);
  }
}
