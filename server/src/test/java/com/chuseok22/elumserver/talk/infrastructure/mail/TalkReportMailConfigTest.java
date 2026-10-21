package com.chuseok22.elumserver.talk.infrastructure.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import com.chuseok22.elumserver.common.infrastructure.properties.TalkProperties;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.mail.javamail.JavaMailSender;

/// 받는 메일과 메일 서버 주소가 둘 다 있을 때만 실제 발송기를 쓴다.
class TalkReportMailConfigTest {

  private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
    .withUserConfiguration(TalkReportMailConfig.class)
    .withBean(JavaMailSender.class, () -> mock(JavaMailSender.class));

  @Test
  @DisplayName("받는 메일과 메일 서버가 모두 있으면 SmtpTalkReportMailer")
  void bothConfigured_usesSmtp() {
    contextRunner
      .withBean(TalkProperties.class, () -> new TalkProperties(null, "ops@example.com", null))
      .withPropertyValues("spring.mail.host=smtp.example.com")
      .run(context -> assertThat(context.getBean(TalkReportMailer.class)).isInstanceOf(SmtpTalkReportMailer.class));
  }

  @Test
  @DisplayName("메일 서버 주소가 비면 NoOpTalkReportMailer")
  void blankMailHost_usesNoOp() {
    contextRunner
      .withBean(TalkProperties.class, () -> new TalkProperties(null, "ops@example.com", null))
      .withPropertyValues("spring.mail.host=")
      .run(context -> assertThat(context.getBean(TalkReportMailer.class)).isInstanceOf(NoOpTalkReportMailer.class));
  }

  @Test
  @DisplayName("받는 메일이 비면 NoOpTalkReportMailer")
  void blankRecipient_usesNoOp() {
    contextRunner
      .withBean(TalkProperties.class, () -> new TalkProperties(null, " ", null))
      .withPropertyValues("spring.mail.host=smtp.example.com")
      .run(context -> assertThat(context.getBean(TalkReportMailer.class)).isInstanceOf(NoOpTalkReportMailer.class));
  }
}
