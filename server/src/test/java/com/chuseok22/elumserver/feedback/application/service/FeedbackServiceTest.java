package com.chuseok22.elumserver.feedback.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.feedback.application.dto.request.FeedbackRequest;
import com.chuseok22.elumserver.feedback.infrastructure.entity.Feedback;
import com.chuseok22.elumserver.feedback.infrastructure.repository.FeedbackRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class FeedbackServiceTest {

  private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 8, 15, 30);
  private static final Clock CLOCK = Clock.fixed(NOW.atZone(ZoneId.systemDefault()).toInstant(), ZoneId.systemDefault());

  @Mock
  private FeedbackRepository repository;

  private FeedbackService service;

  @BeforeEach
  void setUp() {
    service = new FeedbackService(repository, CLOCK);
  }

  private static FeedbackRequest request(String message, String appLog, String version, String os) {
    return new FeedbackRequest(message, appLog, version, os);
  }

  private void stubSave() {
    when(repository.save(any(Feedback.class))).thenAnswer(inv -> {
      Feedback saved = inv.getArgument(0);
      saved.setId("f1");
      return saved;
    });
  }

  @Test
  @DisplayName("정상 요청은 저장하고 id 를 돌려준다")
  void submit_saves() {
    stubSave();

    String id = service.submit("m1", request(" 느려요 ", "log line", "1.0.1", "iOS 18"));

    ArgumentCaptor<Feedback> captor = ArgumentCaptor.forClass(Feedback.class);
    verify(repository).save(captor.capture());
    assertThat(id).isEqualTo("f1");
    assertThat(captor.getValue().getMemberId()).isEqualTo("m1");
    assertThat(captor.getValue().getMessage()).isEqualTo("느려요");
    assertThat(captor.getValue().getAppLog()).isEqualTo("log line");
    assertThat(captor.getValue().getAppVersion()).isEqualTo("1.0.1");
    assertThat(captor.getValue().getOs()).isEqualTo("iOS 18");
  }

  @Test
  @DisplayName("글이 null 이거나 비었거나 공백뿐이면 FEEDBACK_MESSAGE_EMPTY")
  void submit_emptyMessage() {
    for (String message : new String[] {null, "", "   \n\t "}) {
      assertThatThrownBy(() -> service.submit("m1", request(message, null, null, null)))
        .isInstanceOfSatisfying(CustomException.class,
          e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.FEEDBACK_MESSAGE_EMPTY));
    }
    verify(repository, never()).save(any());
  }

  @Test
  @DisplayName("2000자는 저장하고 2001자는 FEEDBACK_MESSAGE_TOO_LONG")
  void submit_messageLength() {
    stubSave();
    service.submit("m1", request("가".repeat(2000), null, null, null));

    assertThatThrownBy(() -> service.submit("m1", request("가".repeat(2001), null, null, null)))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.FEEDBACK_MESSAGE_TOO_LONG));
  }

  @Test
  @DisplayName("로그는 UTF-8 바이트로 256KB 까지, 넘으면 FEEDBACK_LOG_TOO_LARGE")
  void submit_logSize() {
    stubSave();
    service.submit("m1", request("의견", "a".repeat(262144), null, null));

    // 한글 한 글자는 3바이트라 글자 수는 적어도 바이트로는 넘는다.
    assertThatThrownBy(() -> service.submit("m1", request("의견", "가".repeat(87382), null, null)))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.FEEDBACK_LOG_TOO_LARGE));
    assertThatThrownBy(() -> service.submit("m1", request("의견", "a".repeat(262145), null, null)))
      .isInstanceOf(CustomException.class);
  }

  @Test
  @DisplayName("앱 버전과 OS 는 길면 거절하지 않고 잘라 저장한다")
  void submit_truncatesVersionAndOs() {
    stubSave();

    service.submit("m1", request("의견", null, "v".repeat(40), "o".repeat(100)));

    ArgumentCaptor<Feedback> captor = ArgumentCaptor.forClass(Feedback.class);
    verify(repository).save(captor.capture());
    assertThat(captor.getValue().getAppVersion()).hasSize(32);
    assertThat(captor.getValue().getOs()).hasSize(64);
    assertThat(captor.getValue().getAppLog()).isNull();
  }

  @Test
  @DisplayName("오늘 0시 이후 20건을 이미 보냈으면 FEEDBACK_RATE_LIMITED")
  void submit_rateLimited() {
    when(repository.countByMemberIdAndCreatedAtGreaterThanEqual(eq("m1"), eq(NOW.toLocalDate().atStartOfDay())))
      .thenReturn(20L);

    assertThatThrownBy(() -> service.submit("m1", request("의견", null, null, null)))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.FEEDBACK_RATE_LIMITED));
    verify(repository, never()).save(any());
  }

  @Test
  @DisplayName("19건까지는 보낼 수 있다")
  void submit_underLimit() {
    when(repository.countByMemberIdAndCreatedAtGreaterThanEqual(eq("m1"), any())).thenReturn(19L);
    stubSave();

    assertThat(service.submit("m1", request("의견", null, null, null))).isEqualTo("f1");
  }

  @Test
  @DisplayName("없는 id 를 조회하거나 지우면 FEEDBACK_NOT_FOUND")
  void getAndDelete_notFound() {
    when(repository.findById("nope")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.get("nope")).isInstanceOfSatisfying(CustomException.class,
      e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.FEEDBACK_NOT_FOUND));
    assertThatThrownBy(() -> service.delete("nope")).isInstanceOf(CustomException.class);
    verify(repository, never()).delete(any());
  }

  @Test
  @DisplayName("있는 의견은 삭제한다")
  void delete_removes() {
    Feedback feedback = new Feedback();
    feedback.setId("f1");
    when(repository.findById("f1")).thenReturn(Optional.of(feedback));

    service.delete("f1");

    verify(repository).delete(feedback);
  }
}
