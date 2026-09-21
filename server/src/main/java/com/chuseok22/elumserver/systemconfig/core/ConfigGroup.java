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
  PLAN_FREE("Free 플랜 한도"),
  PLAN_PRO("Pro 플랜 한도"),
  APP_CONTROL("앱 점검·버전"),
  // 앱이 서버에서 받아 쓰는 시간값. 전에는 앱의 .env 에 있어 바꾸려면 다시 빌드해야 했다.
  APP_TUNING("앱 대기·연출 시간"),
  ;

  private final String label;
}
