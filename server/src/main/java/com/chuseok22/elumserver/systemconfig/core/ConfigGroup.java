package com.chuseok22.elumserver.systemconfig.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

// 관리자 시스템 설정 화면에서 카드 단위로 묶어 보여주기 위한 설정 그룹.
@Getter
@AllArgsConstructor
public enum ConfigGroup {

  GEMINI_TEXT("Gemini 텍스트"),
  GEMINI_IMAGE("Gemini 이미지"),
  LOCAL_LLM("로컬 LLM"),
  IMAGE_PROVIDER("이미지 생성 제공자"),
  TEXT_PROVIDER("텍스트 생성 제공자"),
  PRICING("AI 요금 단가"),
  // 탈퇴 계정 보관.
  MEMBER("회원"),
  PLAN_FREE("Free 플랜 한도"),
  PLAN_PRO("Pro 플랜 한도"),
  AI_BUDGET("AI 비용 상한"),
  APP_CONTROL("앱 점검·버전"),
  // 앱이 서버에서 받아 쓰는 시간값. 서버가 주므로 바꿔도 앱을 다시 빌드하지 않는다.
  APP_TUNING("앱 대기·연출 시간"),
  // 보호자 홈 공지 팝업. 공지 내용은 "공지 관리" 화면에서, 팝업 전체에 걸리는 값만 여기에 둔다.
  NOTICE("앱 공지"),
  // 보상형 광고를 보면 AI 생성 크레딧을 주는 기능.
  AD_REWARD("광고 보상"),
  // 일과를 만들 수 있는 언어.
  LANGUAGE("언어"),
  ;

  private final String label;
}
