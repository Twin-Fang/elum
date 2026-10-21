package com.chuseok22.elumserver.systemconfig.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 문자열 설정의 형식 규칙: 비울 수 있는지, 화면에 보일 형식 안내
 * 검사 자체는 SystemConfigValueValidator 한 곳에서 (저장할 때만, 읽을 때는 경고 표시만)
 */
@Getter
@AllArgsConstructor
public enum ConfigFormat {

  // 형식 검사 없음 (빈 값·길이만)
  FREE_TEXT(false, ""),
  // 앱 버전. 비우면 막지 않음·권하지 않음
  APP_VERSION(true, "숫자.숫자.숫자 (예: 2.69.1)"),
  // 플랫폼 공식 스토어 주소 (StoreUrlPolicy). 비우면 앱에 넣어 둔 주소
  STORE_URL(true, "플랫폼 공식 스토어 주소"),
  // 쉼표 목록: ca-app-pub-숫자/숫자 또는 뒤의 숫자만
  AD_UNIT_LIST(false, "쉼표로 나눈 광고 단위 (ca-app-pub-…/숫자 또는 숫자)"),
  // 쉼표 목록: 회원 ID(UUID). 저장 시 존재 여부는 관리자 화면이 따로 확인
  MEMBER_ID_LIST(true, "쉼표로 나눈 회원 ID"),
  // 쉼표 목록: 언어 코드 (EnabledLocales)
  CONTENT_LOCALE_LIST(false, "쉼표로 나눈 언어 코드 (ko,en,ja,zh,es)"),
  ;

  private final boolean isBlankAllowed;
  private final String formatHint;
}
