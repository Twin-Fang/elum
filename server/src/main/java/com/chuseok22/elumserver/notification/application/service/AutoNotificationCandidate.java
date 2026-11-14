package com.chuseok22.elumserver.notification.application.service;

import java.time.LocalDate;

/**
 * 자동 알림 받을 사람 한 명과 문구 값: 회원 id, 이룸이 이름, 일과 제목, {날짜} 값 (없으면 null)
 * 날짜는 받는 사람 언어로 바꿔 넣으므로 글자가 아닌 날짜로 들고 감
 */
public record AutoNotificationCandidate(String memberId, String childName, String routineTitle, LocalDate date) {
}
