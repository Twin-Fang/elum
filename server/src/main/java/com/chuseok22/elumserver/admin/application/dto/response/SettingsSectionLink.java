package com.chuseok22.elumserver.admin.application.dto.response;

/**
 * 시스템 설정 화면의 "다른 화면에서 관리하는 설정" 한 칸: 화면 이름·주소, 설정 수, 기본값과 다른 수
 */
public record SettingsSectionLink(
  String label,
  String path,
  long settingCount,
  long differsFromDefaultCount
) {
}
