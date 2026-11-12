package com.chuseok22.elumserver.notification.application.service;

/**
 * 운영자 알림 보낸 결과: 저장한 알림 id, 알림함에 기록된 사람 수, 기기 성공 수, 기기 실패 수
 */
public record AdminMessageSendResult(String messageId, int recordedMemberCount, int sentDeviceCount,
  int failedDeviceCount) {
}
