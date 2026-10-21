package com.chuseok22.elumserver.feedback.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.feedback.application.dto.request.FeedbackRequest;
import com.chuseok22.elumserver.feedback.core.FeedbackStatus;
import com.chuseok22.elumserver.feedback.infrastructure.entity.Feedback;
import com.chuseok22.elumserver.feedback.infrastructure.repository.FeedbackRepository;
import com.chuseok22.elumserver.notification.core.event.FeedbackResolvedEvent;
import com.chuseok22.elumserver.systemconfig.application.service.UsageLimitSettings;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

@ExtendWith(MockitoExtension.class)
class FeedbackServiceTest {

  private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 8, 15, 30);
  private static final Clock CLOCK = Clock.fixed(NOW.atZone(ZoneId.systemDefault()).toInstant(), ZoneId.systemDefault());

  @Mock
  private FeedbackRepository repository;
  @Mock
  private ApplicationEventPublisher eventPublisher;

  private FeedbackService service;

  @BeforeEach
  void setUp() {
    service = new FeedbackService(repository, CLOCK, eventPublisher, UsageLimitSettings.fromDefaults());
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

  private Feedback storedFeedback(String id) {
    Feedback feedback = new Feedback();
    feedback.setId(id);
    when(repository.findById(id)).thenReturn(Optional.of(feedback));
    return feedback;
  }

  @Test
  @DisplayName("새 의견은 처리 상태가 NEW 이고 변경 기록이 없다 (기존 행도 V40 이 NEW 로 채운다)")
  void newFeedback_startsAsNew() {
    Feedback feedback = new Feedback();

    assertThat(feedback.getStatus()).isEqualTo(FeedbackStatus.NEW);
    assertThat(feedback.getStatusChangedAt()).isNull();
    assertThat(feedback.getStatusChangedBy()).isNull();
  }

  @Test
  @DisplayName("처리 상태를 바꾸면 상태와 변경자·변경 시각이 남는다")
  void changeStatus_recordsActorAndTime() {
    Feedback feedback = storedFeedback("f1");

    service.changeStatus("f1", FeedbackStatus.IN_PROGRESS, "kimchi");

    assertThat(feedback.getStatus()).isEqualTo(FeedbackStatus.IN_PROGRESS);
    assertThat(feedback.getStatusChangedBy()).isEqualTo("kimchi");
    assertThat(feedback.getStatusChangedAt()).isEqualTo(NOW);
  }

  @Test
  @DisplayName("NEW > IN_PROGRESS > DONE > NEW 어느 방향이든 바꿀 수 있다 (끝난 의견 다시 열기 포함)")
  void changeStatus_anyTransition() {
    Feedback feedback = storedFeedback("f1");

    for (FeedbackStatus next : List.of(FeedbackStatus.IN_PROGRESS, FeedbackStatus.DONE, FeedbackStatus.NEW,
      FeedbackStatus.DONE)) {
      service.changeStatus("f1", next, "kimchi");
      assertThat(feedback.getStatus()).isEqualTo(next);
    }
  }

  @Test
  @DisplayName("같은 상태로 바꾸면 마지막 변경 기록을 건드리지 않는다")
  void changeStatus_sameStatus_keepsLastChange() {
    Feedback feedback = storedFeedback("f1");
    feedback.setStatus(FeedbackStatus.DONE);
    feedback.setStatusChangedBy("first");
    feedback.setStatusChangedAt(NOW.minusDays(1));

    service.changeStatus("f1", FeedbackStatus.DONE, "second");

    assertThat(feedback.getStatusChangedBy()).isEqualTo("first");
    assertThat(feedback.getStatusChangedAt()).isEqualTo(NOW.minusDays(1));
  }

  @Test
  @DisplayName("처리 완료로 바꾸면 의견을 보낸 사람 id 로 의견 처리 이벤트가 나간다")
  void changeStatus_toDone_publishesFeedbackResolved() {
    Feedback feedback = storedFeedback("f1");
    feedback.setMemberId("member-1");

    service.changeStatus("f1", FeedbackStatus.DONE, "kimchi");

    verify(eventPublisher).publishEvent(new FeedbackResolvedEvent("f1", "member-1"));
  }

  @Test
  @DisplayName("처리 중으로 바꾸면 이벤트가 나가지 않는다")
  void changeStatus_toInProgress_publishesNothing() {
    storedFeedback("f1");

    service.changeStatus("f1", FeedbackStatus.IN_PROGRESS, "kimchi");

    verify(eventPublisher, never()).publishEvent(any(Object.class));
  }

  @Test
  @DisplayName("이미 처리 완료인 의견을 같은 상태로 바꾸면 이벤트가 나가지 않는다")
  void changeStatus_sameStatus_publishesNothing() {
    Feedback feedback = storedFeedback("f1");
    feedback.setStatus(FeedbackStatus.DONE);

    service.changeStatus("f1", FeedbackStatus.DONE, "second");

    verify(eventPublisher, never()).publishEvent(any(Object.class));
  }

  @Test
  @DisplayName("없는 의견의 상태를 바꾸면 FEEDBACK_NOT_FOUND")
  void changeStatus_notFound() {
    when(repository.findById("nope")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> service.changeStatus("nope", FeedbackStatus.DONE, "kimchi"))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.FEEDBACK_NOT_FOUND));
  }

  @Test
  @DisplayName("관리자 검색: 조건이 없으면 전체 상태·빈 패턴·끝값 기간으로, 있으면 그 조건 그대로 묻고 음수 페이지는 0으로")
  void search_translatesConditions() {
    when(repository.searchForAdmin(anyBoolean(), any(), any(), any(), any(), anyBoolean(), any(), anyBoolean(), any(),
      any(Pageable.class))).thenReturn(new PageImpl<>(List.of()));
    ArgumentCaptor<Collection<FeedbackStatus>> statuses = ArgumentCaptor.forClass(Collection.class);
    ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);

    service.search(FeedbackAdminSearch.none(), Sort.by("createdAt"), 2);
    verify(repository).searchForAdmin(eq(false), eq(""), statuses.capture(),
      eq(LocalDateTime.of(2000, 1, 1, 0, 0)), eq(LocalDateTime.of(9999, 1, 1, 0, 0)),
      eq(false), eq(""), eq(false), eq(""), pageable.capture());
    assertThat(statuses.getValue()).containsExactlyInAnyOrder(FeedbackStatus.values());
    assertThat(pageable.getValue().getPageNumber()).isEqualTo(2);
    assertThat(pageable.getValue().getPageSize()).isEqualTo(FeedbackService.ADMIN_PAGE_SIZE);

    org.mockito.Mockito.clearInvocations(repository);
    LocalDateTime from = LocalDateTime.of(2026, 10, 1, 0, 0);
    LocalDateTime to = LocalDateTime.of(2026, 10, 3, 0, 0);
    service.search(new FeedbackAdminSearch("%느림\\%", FeedbackStatus.DONE, from, to, "1.0%", "ios%"),
      Sort.by("createdAt"), -3);
    verify(repository).searchForAdmin(eq(true), eq("%느림\\%"), statuses.capture(), eq(from), eq(to),
      eq(true), eq("1.0%"), eq(true), eq("ios%"), pageable.capture());
    assertThat(statuses.getValue()).containsExactly(FeedbackStatus.DONE);
    // 음수 페이지는 0으로 보정
    assertThat(pageable.getValue().getPageNumber()).isZero();
  }

  @Test
  @DisplayName("상태 이름 해석: 알 수 없거나 비면 빈 값")
  void statusFromName() {
    assertThat(FeedbackStatus.fromName("DONE")).contains(FeedbackStatus.DONE);
    assertThat(FeedbackStatus.fromName(" IN_PROGRESS ")).contains(FeedbackStatus.IN_PROGRESS);
    assertThat(FeedbackStatus.fromName("done")).isEmpty();
    assertThat(FeedbackStatus.fromName(null)).isEmpty();
    assertThat(FeedbackStatus.fromName("")).isEmpty();
  }
}
