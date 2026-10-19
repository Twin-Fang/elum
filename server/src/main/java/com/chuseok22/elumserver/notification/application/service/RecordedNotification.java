package com.chuseok22.elumserver.notification.application.service;

/**
 * 기록 결과 한 건: 알림 id, 받는 사람, 모인 횟수, 푸시 대상 여부
 * shouldPush 는 새 줄이거나 묶음에 새 발생이 더해졌을 때만 true
 */
public record RecordedNotification(String notificationId, String recipientMemberId, int count, boolean shouldPush) {
}
