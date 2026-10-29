package com.chuseok22.elumserver.talk.infrastructure.mail;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Properties;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mail.javamail.JavaMailSenderImpl;

/// 메일 발송기 생성: 접속 정보, 인증·STARTTLS, 타임아웃 3종이 들어간다.
class SmtpMailSenderFactoryTest {

  @Test
  @DisplayName("호스트·포트·계정과 STARTTLS·인증·타임아웃을 채운다")
  void create_setsConnectionAndProperties() {
    JavaMailSenderImpl sender = (JavaMailSenderImpl) new SmtpMailSenderFactory()
      .create("smtp.example.com", 587, "user@example.com", "secret-pw");

    assertThat(sender.getHost()).isEqualTo("smtp.example.com");
    assertThat(sender.getPort()).isEqualTo(587);
    assertThat(sender.getUsername()).isEqualTo("user@example.com");
    Properties properties = sender.getJavaMailProperties();
    assertThat(properties.getProperty("mail.smtp.auth")).isEqualTo("true");
    assertThat(properties.getProperty("mail.smtp.starttls.enable")).isEqualTo("true");
    assertThat(properties.getProperty("mail.smtp.connectiontimeout")).isEqualTo("5000");
    assertThat(properties.getProperty("mail.smtp.timeout")).isEqualTo("10000");
    assertThat(properties.getProperty("mail.smtp.writetimeout")).isEqualTo("10000");
  }
}
