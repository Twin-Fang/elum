package com.chuseok22.elumserver.admin.application.list;

import java.util.Map;

/**
 * 공통 표의 한 행: 열 키별 표시 문자열, 첫 칸에 걸 링크(없으면 null), 다른 칸에 거는 링크(열 키별, 없으면 빈 맵)
 * cellTones: 배지로 그릴 칸의 색 (열 키 > success·error·warning·info·ghost, 없으면 글자 그대로)
 */
public record AdminListRow(
  String linkUrl, Map<String, String> cells, Map<String, String> cellLinks, Map<String, String> cellTones
) {

  public AdminListRow {
    cells = cells == null ? Map.of() : Map.copyOf(cells);
    cellLinks = cellLinks == null ? Map.of() : Map.copyOf(cellLinks);
    cellTones = cellTones == null ? Map.of() : Map.copyOf(cellTones);
  }

  public AdminListRow(String linkUrl, Map<String, String> cells, Map<String, String> cellLinks) {
    this(linkUrl, cells, cellLinks, Map.of());
  }

  public AdminListRow(String linkUrl, Map<String, String> cells) {
    this(linkUrl, cells, Map.of(), Map.of());
  }
}
