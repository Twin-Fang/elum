package com.chuseok22.elumserver.talk.infrastructure.mail;

/** 메일 설정이 없을 때의 발송기: 아무것도 보내지 않음 */
public class NoOpTalkReportMailer implements TalkReportMailer {

  @Override
  public void sendReportNotice(TalkReportNotice notice) {
    // 설정 누락 경고는 빈 생성 때 한 번 남김
  }
}
