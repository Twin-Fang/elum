package com.chuseok22.elumserver.admin.application.dto.response;

/**
 * 첫날 한 일별 재방문 한 줄 (#1471): 묶음 이름, 인원, 7일 재방문 대상·인원, 칸 문구
 * 7일 재방문 = 가입 다음 날 ~ 7일째 방문 (대시보드 7일 리텐션과 같은 기준). 대상 0명이면 "-"
 */
public record AdminFirstDayActivationGroup(
  String label, long memberCount, long maturedCount, long retainedCount, Integer retainedPercent, String retainedText
) {

  /// 대상(가입 뒤 8일 넘게 지남 + 방문 기록 안)이 없을 때 칸 문구
  public static final String NO_MATURED_TEXT = "-";

  /** 묶음 숫자 > 줄 (비율은 대상 대비, 대상 0명이면 null) */
  public static AdminFirstDayActivationGroup of(String label, long memberCount, long maturedCount, long retainedCount) {
    if (maturedCount == 0) {
      return new AdminFirstDayActivationGroup(label, memberCount, 0, 0, null, NO_MATURED_TEXT);
    }
    int percent = (int) Math.round(retainedCount * 100.0 / maturedCount);
    return new AdminFirstDayActivationGroup(label, memberCount, maturedCount, retainedCount, percent,
      percent + "% (" + retainedCount + "/" + maturedCount + "명)");
  }
}
