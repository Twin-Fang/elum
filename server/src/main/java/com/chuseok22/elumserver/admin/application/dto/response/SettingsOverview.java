package com.chuseok22.elumserver.admin.application.dto.response;

import java.util.List;

/**
 * 설정 화면 상단 요약: 기본값과 다른 설정 수, 지금 적용 중 항목, Free/Pro 비교
 */
public record SettingsOverview(
  int differsFromDefaultCount,
  List<Highlight> highlights,
  List<PlanRow> planComparison
) {

  /** 요약 항목 하나. isOn 은 켜진 상태(강조), isDifferent 는 기본값과 다름 */
  public record Highlight(String key, String label, String valueText, boolean isOn, boolean isDifferent) {
  }

  /** Free/Pro 비교 표의 한 줄. 같은 항목의 두 플랜 값 */
  public record PlanRow(
    String label,
    String freeKey,
    String freeValueText,
    boolean isFreeDifferent,
    String proKey,
    String proValueText,
    boolean isProDifferent
  ) {
  }
}
