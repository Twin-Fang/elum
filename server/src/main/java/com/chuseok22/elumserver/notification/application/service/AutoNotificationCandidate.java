package com.chuseok22.elumserver.notification.application.service;

/**
 * 자동 알림 받을 사람 한 명과 문구 값: 회원 id, 이룸이 이름, 일과 제목, 날짜 글자 (없으면 null)
 */
public record AutoNotificationCandidate(String memberId, String childName, String routineTitle, String dateText) {
}
