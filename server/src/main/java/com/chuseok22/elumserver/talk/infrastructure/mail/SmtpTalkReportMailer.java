package com.chuseok22.elumserver.talk.infrastructure.mail;

import lombok.extern.slf4j.Slf4j;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;

/**
 * SMTP 신고 메일 발송: 제목·평문 본문 조립 > 운영 메일로 발송
 * 신고자 정보는 본문에 넣지 않고, 발송 실패는 로그만 남김
 */
@Slf4j
public class SmtpTalkReportMailer implements TalkReportMailer {

  private static final String SUBJECT_PREFIX = "[이룸] 이야기 신고 접수 : ";

  private final JavaMailSender javaMailSender;
  private final String recipientAddress;
  // 비면 메일 서버 기본 발신자 사용
  private final String senderAddress;

  public SmtpTalkReportMailer(JavaMailSender javaMailSender, String recipientAddress, String senderAddress) {
    this.javaMailSender = javaMailSender;
    this.recipientAddress = recipientAddress;
    this.senderAddress = senderAddress;
  }

  @Override
  public void sendReportNotice(TalkReportNotice notice) {
    try {
      javaMailSender.send(toMessage(notice));
    } catch (RuntimeException e) {
      log.warn("[talk report mail] failed : {}", notice.reportId());
    }
  }

  private SimpleMailMessage toMessage(TalkReportNotice notice) {
    SimpleMailMessage message = new SimpleMailMessage();
    if (senderAddress != null && !senderAddress.isBlank()) {
      message.setFrom(senderAddress);
    }
    message.setTo(recipientAddress);
    message.setSubject(SUBJECT_PREFIX + notice.reasonLabel());
    message.setText(toBody(notice));
    return message;
  }

  private String toBody(TalkReportNotice notice) {
    return """
      이야기 신고가 접수됐어요.

      사유 : %s
      대상 : %s
      글 제목 : %s
      내용 일부 : %s

      관리자 화면 : %s
      """.formatted(notice.reasonLabel(), notice.targetType(), nullToEmpty(notice.postTitle()),
      nullToEmpty(notice.excerpt()), notice.adminUrl());
  }

  private String nullToEmpty(String text) {
    return text == null ? "" : text;
  }
}
