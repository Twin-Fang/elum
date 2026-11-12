package com.chuseok22.elumserver.notification.application.service;

/**
 * 운영자 알림 도달 미리 계산: 받는 사람 수, 그중 알림을 켠 사람 수, 켠 사람들의 보호자 기기 수
 */
public record AdminMessageReach(int memberCount, int pushEnabledMemberCount, int deviceCount) {
}
