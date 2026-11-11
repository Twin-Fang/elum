package com.chuseok22.elumserver.systemconfig.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

// 관리자 시스템 설정 화면에서 카드 단위로 묶어 보여주기 위한 설정 그룹.
@Getter
@AllArgsConstructor
public enum ConfigGroup {

  GEMINI_TEXT("Gemini 텍스트"),
  GEMINI_IMAGE("Gemini 이미지"),
  IMAGE_PROVIDER("이미지 생성 제공자"),
  TEXT_PROVIDER("텍스트 생성 제공자"),
  PRICING("AI 요금 단가"),
  // 탈퇴 계정 보관.
  MEMBER("회원"),
  PLAN_FREE("Free 플랜 한도"),
  PLAN_PRO("Pro 플랜 한도"),
  // 구독 행이 없는 새 회원에게 기간 한정으로 Pro 를 주는 이벤트.
  SIGNUP_PRO_EVENT("신규가입 PRO 이벤트"),
  // 결제 전부터 쓴 회원에게 종료 시각까지 Pro 를 주는 선물.
  EXISTING_MEMBER_PRO_GIFT("기존 가입자 Pro 선물"),
  AI_BUDGET("AI 비용 상한"),
  // AI 크레딧 지급 주기 (지급량·단가는 관리자 "크레딧 정책" 화면의 버전 정책이 따로 정한다).
  AI_CREDIT("AI 크레딧"),
  // 호출 비용·남용 방지 한도: 요청 간격, 창당 횟수, 동시 실행 수.
  USAGE_LIMIT("사용 한도·남용 방지"),
  APP_CONTROL("앱 점검·버전"),
  // 서버 이전: 이전 잠금, 파일 내보내기, 새 서버 주소 (관리자 서버 이전 화면에서 고침)
  MIGRATION("서버 이전"),
  // 앱이 서버에서 받아 쓰는 시간값. 서버가 주므로 바꿔도 앱을 다시 빌드하지 않는다.
  APP_TUNING("앱 대기·연출 시간"),
  // 보호자 홈 공지 팝업. 공지 내용은 "공지 관리" 화면에서, 팝업 전체에 걸리는 값만 여기에 둔다.
  NOTICE("앱 공지"),
  // 보상형 광고를 보면 AI 생성 크레딧을 주는 기능.
  AD_REWARD("광고 보상"),
  // 일과를 만들 수 있는 언어.
  LANGUAGE("언어"),
  // 이야기 신고 알림 메일: 켜기, 받는 주소, 보내는 SMTP 계정.
  MAIL("신고 메일"),
  // App Store·Google Play 구독 결제 검증과 결제 알림 (#1071).
  SUBSCRIPTION_STORE("스토어 구독 결제"),
  // 관제소(suh-project-control)가 확인할 일을 모아 가는 연동 (#1229).
  CONTROL_TOWER("관제소 연동"),
  // 주간 리포트 AI 정리 글과 월요일 알림 켜기.
  WEEKLY_REPORT("주간 리포트"),
  ;

  private final String label;
}
