package com.chuseok22.elumserver.talk.infrastructure.mail;

import java.util.Properties;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.JavaMailSenderImpl;
import org.springframework.stereotype.Component;

/**
 * SMTP 발송기 생성: 접속 정보 + 인증·STARTTLS·타임아웃 3종
 * 설정이 화면에서 바뀌므로 발송마다 새로 만듦 (스프링 자동 구성 빈은 쓰지 않음)
 */
@Component
public class SmtpMailSenderFactory {

  // 응답 없는 메일 서버가 공용 알림 스레드풀을 붙잡지 않게 (ms)
  private static final String CONNECTION_TIMEOUT_MILLISECONDS = "5000";
  private static final String READ_TIMEOUT_MILLISECONDS = "10000";
  private static final String WRITE_TIMEOUT_MILLISECONDS = "10000";

  public JavaMailSender create(String host, int port, String username, String password) {
    JavaMailSenderImpl sender = new JavaMailSenderImpl();
    sender.setHost(host);
    sender.setPort(port);
    sender.setUsername(username);
    sender.setPassword(password);
    Properties properties = sender.getJavaMailProperties();
    properties.setProperty("mail.smtp.auth", "true");
    properties.setProperty("mail.smtp.starttls.enable", "true");
    // STARTTLS 없이 평문으로 계정이 넘어가지 않게 (다운그레이드 차단)
    properties.setProperty("mail.smtp.starttls.required", "true");
    properties.setProperty("mail.smtp.connectiontimeout", CONNECTION_TIMEOUT_MILLISECONDS);
    properties.setProperty("mail.smtp.timeout", READ_TIMEOUT_MILLISECONDS);
    properties.setProperty("mail.smtp.writetimeout", WRITE_TIMEOUT_MILLISECONDS);
    return sender;
  }
}
