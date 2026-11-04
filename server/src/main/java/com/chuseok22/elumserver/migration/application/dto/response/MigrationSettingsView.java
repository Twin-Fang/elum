package com.chuseok22.elumserver.migration.application.dto.response;

import java.util.List;

/**
 * 이전 설정 3개 읽기 전용 표시 (#1062): 이전 잠금, 이전 파일 내보내기, 새 서버 주소
 * 못 읽으면 rows 비움 + errorMessage
 */
public record MigrationSettingsView(List<Row> rows, String errorMessage) {

  /// 설정 1줄: 표시 이름(ConfigKey 라벨), 값 글, 켜짐 강조 여부
  public record Row(String label, String valueText, boolean isHighlighted) {
  }

  public boolean isReadable() {
    return errorMessage == null;
  }
}
