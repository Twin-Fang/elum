package com.chuseok22.elumserver.notification.core;

/**
 * 이룸이 기기 알림 받을 수 있는 상태 3개: 연결 기기 없음, 연결됐지만 알림 꺼짐(등록 토큰 없음), 켜짐
 * 서버가 아는 것은 토큰 등록 여부뿐 (기기 설정에서 나중에 끈 것은 다음 발송 실패 전까지 모름)
 */
public enum ElumiNotificationState {
  NO_DEVICE,
  OFF,
  ON
}
