package com.chuseok22.elumserver.admin.application.dto.response;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/**
 * 한 화면의 설정 칸: 그 화면 설정 행, 필터 칩(묶음), 규칙 경고 수, 저장 뒤 다시 받을 주소
 * 읽기 실패면 행 없이 loadErrorMessage 만 (화면의 나머지는 그대로)
 */
public record SettingsEditorView(
  /** 저장 뒤 행·요약을 다시 받을 화면 경로 */
  String refreshPath,
  List<SettingRow> rows,
  /** 필터 칩: 묶음 이름 > 표시 이름 (선언 순서) */
  Map<String, String> groupLabelByName,
  long ruleWarningCount,
  /** "오늘 변경" 칩 기준일 */
  LocalDate today,
  String loadErrorMessage
) {

  public static SettingsEditorView failed(String refreshPath, String loadErrorMessage) {
    return new SettingsEditorView(refreshPath, List.of(), Map.of(), 0, LocalDate.now(), loadErrorMessage);
  }

  public boolean isLoaded() {
    return loadErrorMessage == null;
  }

  /** 묶음이 하나뿐이면 묶음 칩을 숨김 */
  public boolean hasSeveralGroups() {
    return groupLabelByName.size() > 1;
  }
}
