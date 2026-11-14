package com.chuseok22.elumserver.admin.application.dto.response;

import java.util.List;

/**
 * 언어 현황 표 한 줄 (언어 하나)
 * DB 칸(프롬프트·약관·공지)은 조회 실패 시 null > 화면에 "확인 못 함"
 *
 * @param isContentEnabled       ENABLED_CONTENT_LOCALES 에 켜져 있는가
 * @param promptRowCount         그 언어에 있는 프롬프트 행 수 (필수 키 기준)
 * @param promptRequiredCount    그 언어에 있어야 하는 프롬프트 키 수
 * @param consentVersions        약관 종류별 그 언어 게시 버전
 * @param isConsentServedInLocale 필수 약관이 다 있어 앱에 그 언어 약관이 나가는가 (아니면 ko 로 대체)
 * @param noticeCount            그 언어 공지 전체 수
 * @param liveNoticeCount        그중 지금 게시 중인 수
 */
public record AdminLocaleStatusRow(
  String code,
  String label,
  boolean isContentEnabled,
  AdminLocaleBundleStatus errorMessages,
  AdminLocaleBundleStatus routinePhrases,
  AdminLocaleBundleStatus pushMessages,
  Integer promptRowCount,
  Integer promptRequiredCount,
  List<AdminLocaleConsentVersion> consentVersions,
  Boolean isConsentServedInLocale,
  Integer noticeCount,
  Integer liveNoticeCount
) {

  public boolean hasPromptStatus() {
    return promptRowCount != null && promptRequiredCount != null;
  }

  public boolean isPromptComplete() {
    return hasPromptStatus() && promptRowCount.equals(promptRequiredCount);
  }
}
