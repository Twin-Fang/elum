package com.chuseok22.elumserver.talk.infrastructure.mail;

import com.chuseok22.elumserver.common.infrastructure.properties.TalkProperties;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.mail.javamail.JavaMailSender;

/**
 * 신고 메일 발송기 선택: 받는 메일(talk.report-mail-to)과 메일 서버(spring.mail.host)가 둘 다 있으면 SMTP, 아니면 NoOp
 * 값이 빈 문자열이어도 spring.mail.host 속성이 "있는 것"으로 잡히므로 조건 애노테이션 대신 값을 직접 확인
 */
@Slf4j
@Configuration
public class TalkReportMailConfig {

  @Bean
  public TalkReportMailer talkReportMailer(
    TalkProperties talkProperties,
    ObjectProvider<JavaMailSender> javaMailSenderProvider,
    @Value("${spring.mail.host:}") String mailHost,
    @Value("${spring.mail.username:}") String mailUsername
  ) {
    JavaMailSender javaMailSender = javaMailSenderProvider.getIfAvailable();
    boolean isMailConfigured = talkProperties.reportMailTo() != null && !mailHost.isBlank() && javaMailSender != null;
    if (!isMailConfigured) {
      log.warn("[talk report mail] disabled : recipient or mail host is not configured");
      return new NoOpTalkReportMailer();
    }
    return new SmtpTalkReportMailer(javaMailSender, talkProperties.reportMailTo(), mailUsername);
  }
}
