package com.chuseok22.elumserver.talk.infrastructure.mail;

import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.Arrays;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;

/**
 * SMTP 신고 메일 발송: 설정 확인 > 제목·평문 본문 조립 > 운영 메일로 발송
 * 설정은 발송마다 시스템 설정에서 읽고, 신고자 정보는 본문에 넣지 않으며, 실패는 로그만 남김
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class SmtpTalkReportMailer implements TalkReportMailer {

  private static final String SUBJECT_PREFIX = "[이룸] 이야기 신고 접수 : ";
  // 받는 주소 구분자 (쉼표로 여러 개)
  private static final String RECIPIENT_DELIMITER = ",";

  private final SystemConfigService systemConfigService;
  private final SmtpMailSenderFactory smtpMailSenderFactory;

  @Override
  public void sendReportNotice(TalkReportNotice notice) {
    try {
      // 꺼짐 또는 필수값 누락 > 보내지 않음
      if (!systemConfigService.getBoolean(ConfigKey.TALK_REPORT_MAIL_ENABLED)) {
        log.debug("[talk report mail] skipped : disabled");
        return;
      }
      String[] recipientAddresses = toRecipientAddresses(systemConfigService.getString(ConfigKey.TALK_REPORT_MAIL_TO));
      String host = systemConfigService.getString(ConfigKey.MAIL_SMTP_HOST).trim();
      String username = systemConfigService.getString(ConfigKey.MAIL_SMTP_USERNAME).trim();
      String password = systemConfigService.getSecret(ConfigKey.MAIL_SMTP_PASSWORD);
      if (recipientAddresses.length == 0 || host.isEmpty() || username.isEmpty() || password.isBlank()) {
        log.warn("[talk report mail] skipped : recipient, host, username or password is not configured");
        return;
      }
      // 발송 (보내는 주소는 SMTP 계정)
      JavaMailSender javaMailSender = smtpMailSenderFactory.create(
        host, systemConfigService.getInt(ConfigKey.MAIL_SMTP_PORT), username, password);
      javaMailSender.send(toMessage(notice, recipientAddresses, username));
    } catch (RuntimeException e) {
      log.warn("[talk report mail] failed : {} ({})", notice.reportId(), e.getClass().getSimpleName());
    }
  }

  // 쉼표 목록 > 주소 배열 (공백·빈 칸 제외)
  private String[] toRecipientAddresses(String recipientAddressText) {
    return Arrays.stream(recipientAddressText.split(RECIPIENT_DELIMITER))
      .map(String::trim)
      .filter(address -> !address.isEmpty())
      .toArray(String[]::new);
  }

  private SimpleMailMessage toMessage(TalkReportNotice notice, String[] recipientAddresses, String senderAddress) {
    SimpleMailMessage message = new SimpleMailMessage();
    message.setFrom(senderAddress);
    message.setTo(recipientAddresses);
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
