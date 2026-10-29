package com.chuseok22.elumserver.talk.infrastructure.mail;

/** 신고 접수 알림 발송: 구현은 실패해도 예외를 밖으로 던지지 않음 */
public interface TalkReportMailer {

  void sendReportNotice(TalkReportNotice notice);
}
