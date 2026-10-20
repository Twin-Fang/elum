package com.chuseok22.elumserver.talk.infrastructure.mail;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mail.MailSendException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;

/// 신고 메일에 신고자 정보가 없고, 본문 일부는 200자로 잘리며, 발송 실패가 밖으로 번지지 않는다.
@ExtendWith(MockitoExtension.class)
class SmtpTalkReportMailerTest {

  @Mock
  private JavaMailSender javaMailSender;

  private SmtpTalkReportMailer smtpTalkReportMailer;

  @BeforeEach
  void setUp() {
    smtpTalkReportMailer = new SmtpTalkReportMailer(javaMailSender, "ops@example.com", "noreply@example.com");
  }

  @Test
  @DisplayName("제목·수신자·본문을 만들고 신고자 정보와 200자 넘는 내용은 담지 않는다")
  void buildsMessageWithoutReporterInfo() {
    String longExcerpt = "가".repeat(250);
    TalkReportNotice notice = new TalkReportNotice("report-1", "댓글", "불쾌한 내용", "버스 타기", longExcerpt,
      "https://api.example.com/admin/talk/posts/post-1");

    smtpTalkReportMailer.sendReportNotice(notice);

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
  @DisplayName("메일 서버가 실패해도 예외를 밖으로 던지지 않는다")
  void mailFailure_doesNotPropagate() {
    doThrow(new MailSendException("smtp down")).when(javaMailSender).send(any(SimpleMailMessage.class));
    TalkReportNotice notice = new TalkReportNotice("report-1", "글", "광고", "제목", "내용", "https://x/admin");

    assertThatCode(() -> smtpTalkReportMailer.sendReportNotice(notice)).doesNotThrowAnyException();
  }
}
