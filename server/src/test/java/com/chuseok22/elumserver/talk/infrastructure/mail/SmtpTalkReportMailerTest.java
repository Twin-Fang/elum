package com.chuseok22.elumserver.talk.infrastructure.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.mail.MailSendException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;

/// 신고 메일: 설정이 꺼졌거나 필수값이 비면 보내지 않고, 보낼 때 신고자 정보·200자 넘는 내용은 빠지며, 실패는 밖으로 번지지 않는다.
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class SmtpTalkReportMailerTest {

  @Mock
  private SystemConfigService systemConfigService;
  @Mock
  private SmtpMailSenderFactory smtpMailSenderFactory;
  @Mock
  private JavaMailSender javaMailSender;

  private SmtpTalkReportMailer smtpTalkReportMailer;

  @BeforeEach
  void setUp() {
    smtpTalkReportMailer = new SmtpTalkReportMailer(systemConfigService, smtpMailSenderFactory);
    when(smtpMailSenderFactory.create(anyString(), anyInt(), anyString(), anyString())).thenReturn(javaMailSender);
    stubConfig(true, "ops@example.com", "smtp.example.com", 587, "noreply@example.com", "app-password");
  }

  private void stubConfig(boolean isEnabled, String to, String host, int port, String username, String password) {
    when(systemConfigService.getBoolean(ConfigKey.TALK_REPORT_MAIL_ENABLED)).thenReturn(isEnabled);
    when(systemConfigService.getString(ConfigKey.TALK_REPORT_MAIL_TO)).thenReturn(to);
    when(systemConfigService.getString(ConfigKey.MAIL_SMTP_HOST)).thenReturn(host);
    when(systemConfigService.getInt(ConfigKey.MAIL_SMTP_PORT)).thenReturn(port);
    when(systemConfigService.getString(ConfigKey.MAIL_SMTP_USERNAME)).thenReturn(username);
    when(systemConfigService.getSecret(ConfigKey.MAIL_SMTP_PASSWORD)).thenReturn(password);
  }

  private static TalkReportNotice notice() {
    return new TalkReportNotice("report-1", "글", "광고", "제목", "내용", "https://x/admin");
  }

  @Test
  @DisplayName("설정값으로 발송기를 만들어 제목·수신자·본문을 보내고 신고자 정보와 200자 넘는 내용은 담지 않는다")
  void buildsMessageWithoutReporterInfo() {
    String longExcerpt = "가".repeat(250);
    TalkReportNotice notice = new TalkReportNotice("report-1", "댓글", "불쾌한 내용", "버스 타기", longExcerpt,
      "https://api.example.com/admin/talk/posts/post-1");

    smtpTalkReportMailer.sendReportNotice(notice);

    verify(smtpMailSenderFactory).create("smtp.example.com", 587, "noreply@example.com", "app-password");
    ArgumentCaptor<SimpleMailMessage> captor = ArgumentCaptor.forClass(SimpleMailMessage.class);
    verify(javaMailSender).send(captor.capture());
    SimpleMailMessage message = captor.getValue();
    assertThat(message.getSubject()).isEqualTo("[이룸] 이야기 신고 접수 : 불쾌한 내용");
    assertThat(message.getTo()).containsExactly("ops@example.com");
    assertThat(message.getFrom()).isEqualTo("noreply@example.com");
    assertThat(message.getText())
      .contains("버스 타기", "댓글", "불쾌한 내용", "https://api.example.com/admin/talk/posts/post-1")
      .contains("가".repeat(200))
      .doesNotContain("가".repeat(201))
      .doesNotContainIgnoringCase("reporter");
  }

  @Test
  @DisplayName("받는 주소를 쉼표로 여러 개 적으면 모두에게 보낸다 (공백·빈 칸 무시)")
  void commaSeparatedRecipients_allReceive() {
    stubConfig(true, " a@example.com, ,b@example.com ", "smtp.example.com", 587, "noreply@example.com", "pw");

    smtpTalkReportMailer.sendReportNotice(notice());

    ArgumentCaptor<SimpleMailMessage> captor = ArgumentCaptor.forClass(SimpleMailMessage.class);
    verify(javaMailSender).send(captor.capture());
    assertThat(captor.getValue().getTo()).containsExactly("a@example.com", "b@example.com");
  }

  @Test
  @DisplayName("꺼져 있으면 발송기를 만들지도 보내지도 않는다")
  void disabled_sendsNothing() {
    stubConfig(false, "ops@example.com", "smtp.example.com", 587, "noreply@example.com", "pw");

    smtpTalkReportMailer.sendReportNotice(notice());

    verifyNoInteractions(smtpMailSenderFactory);
    verify(javaMailSender, never()).send(any(SimpleMailMessage.class));
  }

  @Test
  @DisplayName("받는 주소·호스트·계정·비밀번호 중 하나라도 비면 보내지 않는다")
  void missingRequiredValue_sendsNothing() {
    String[][] cases = {
      {"", "smtp.example.com", "user@example.com", "pw"},
      {" , ", "smtp.example.com", "user@example.com", "pw"},
      {"ops@example.com", "", "user@example.com", "pw"},
      {"ops@example.com", "smtp.example.com", "", "pw"},
      {"ops@example.com", "smtp.example.com", "user@example.com", ""},
    };
    for (String[] values : cases) {
      stubConfig(true, values[0], values[1], 587, values[2], values[3]);

      smtpTalkReportMailer.sendReportNotice(notice());
    }

    verifyNoInteractions(smtpMailSenderFactory);
    verify(javaMailSender, never()).send(any(SimpleMailMessage.class));
  }

  @Test
  @DisplayName("메일 서버가 실패해도 예외를 밖으로 던지지 않는다")
  void mailFailure_doesNotPropagate() {
    doThrow(new MailSendException("smtp down")).when(javaMailSender).send(any(SimpleMailMessage.class));

    assertThatCode(() -> smtpTalkReportMailer.sendReportNotice(notice())).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("설정을 읽다 실패해도 예외를 밖으로 던지지 않는다")
  void configReadFailure_doesNotPropagate() {
    when(systemConfigService.getBoolean(ConfigKey.TALK_REPORT_MAIL_ENABLED)).thenThrow(new IllegalStateException("db"));

    assertThatCode(() -> smtpTalkReportMailer.sendReportNotice(notice())).doesNotThrowAnyException();
  }
}
