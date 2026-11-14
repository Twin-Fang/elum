package com.chuseok22.elumserver.notification.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 자동 알림 종류 9개 (#1275, 리텐션 4종 #1409): 이름, 관리자 화면 조건 설명, 정한 시각에 하루 한 번 도는지. 순서 = 하루 1개 상한에서 먼저 보내는 차례
 * 앱에는 운영자 알림(ADMIN_MESSAGE)으로 감 (알림함 표시는 앱 2.90.0 부터, 그 전 앱은 그 줄만 건너뜀)
 */
@Getter
@AllArgsConstructor
public enum AutoNotificationType {

  // 이룸이가 처음으로 일과를 끝낸 뒤 다음 실행 (정한 시각 없음, 평생 한 번)
  FIRST_ROUTINE_DONE("첫 일과 축하", "이룸이가 처음으로 일과를 끝냈을 때 (평생 한 번, 시각 없이 바로)", false),
  STREAK_AT_RISK("연속 기록 이어 가기", "이룸이가 어제까지 2일 이상 이어서 일과를 마쳤는데 오늘 아직 안 마쳤을 때, 그 이룸이의 보호자", true),
  SENT_NOT_DONE("보낸 일과 아직 시작 전", "오늘 일과를 보냈고 이룸이 기기가 연결돼 있는데, 오늘 이룸이가 카드 하나도 안 마쳤을 때", true),
  LINK_PENDING("이룸이 기기 연결 안내", "처음 일과를 보낸 지 1~3일인데 그 이룸이에 기기 연결도, 마친 일과도 없을 때 (한 번)", true),
  ONBOARDED_NO_ROUTINE("첫 일과 만들기 안내", "온보딩(이룸이 이름 저장)을 마쳤는데 일과를 하나도 안 만든 보호자, 가입 1일째와 3일째", true),
  PRO_GIFT_ENDING("Pro 선물·체험 끝나기 전", "Pro 선물·체험·관리자 발급이 7일 뒤 끝날 때 (그 혜택마다 한 번)", true),
  DAILY_ROUTINE_NUDGE("오늘 일과 보내기", "어제 일과를 보냈는데 오늘 아직 안 보냈을 때 (반복 일과가 있는 보호자 제외)", true),
  TALK_POPULAR("이야기 인기 일과", "최근 7일 안에 3명 이상이 담은 이야기 글이 있을 때, 30일 안에 앱을 연 보호자", true),
  COMEBACK("다시 찾기", "3일 이상 앱을 안 열었을 때 (60일 넘게 안 연 보호자는 제외)", true),
  ;

  private final String label;
  private final String conditionDescription;
  /// true: 정한 시각 이후 하루 한 번, false: 야간이 아니면 실행마다
  private final boolean hasFixedSendTime;
}
