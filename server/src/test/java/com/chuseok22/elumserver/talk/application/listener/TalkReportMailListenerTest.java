package com.chuseok22.elumserver.talk.application.listener;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.properties.TalkProperties;
import com.chuseok22.elumserver.talk.core.TalkReportReason;
import com.chuseok22.elumserver.talk.core.TalkReportTargetType;
import com.chuseok22.elumserver.talk.core.event.TalkReportedEvent;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkComment;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkReport;
import com.chuseok22.elumserver.talk.infrastructure.mail.TalkReportMailer;
import com.chuseok22.elumserver.talk.infrastructure.mail.TalkReportNotice;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkCommentRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkReportRepository;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 신고 이벤트 > 메일 내용 조립(사유 라벨, 글 제목, 댓글·메모 일부, 관리자 링크). 실패는 밖으로 번지지 않는다.
@ExtendWith(MockitoExtension.class)
class TalkReportMailListenerTest {

  @Mock
  private TalkReportRepository talkReportRepository;
  @Mock
  private TalkPostRepository talkPostRepository;
  @Mock
  private TalkCommentRepository talkCommentRepository;
  @Mock
  private TalkReportMailer talkReportMailer;

  private TalkReportMailListener talkReportMailListener;

  @BeforeEach
  void setUp() {
    talkReportMailListener = new TalkReportMailListener(talkReportRepository, talkPostRepository,
      talkCommentRepository, talkReportMailer, new TalkProperties(null, "ops@example.com", "https://api.example.com/"));
  }

  @Test
  @DisplayName("글 신고는 글 제목·메모 일부·관리자 링크를 담고 신고자 id 는 담지 않는다")
  void onReported_post_buildsNotice() {
    when(talkReportRepository.findById("report-1")).thenReturn(Optional.of(report(TalkReportTargetType.POST, "post-1", "post-1")));
    TalkPost post = new TalkPost();
    post.setTitle("버스 타기");
    post.setNote("메모 내용");
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));

    talkReportMailListener.onReported(new TalkReportedEvent("report-1"));

    TalkReportNotice notice = captureNotice();
    assertThat(notice.reportId()).isEqualTo("report-1");
    assertThat(notice.targetType()).isEqualTo("글");
    assertThat(notice.reasonLabel()).isEqualTo(TalkReportReason.OFFENSIVE.getLabel());
    assertThat(notice.postTitle()).isEqualTo("버스 타기");
    assertThat(notice.excerpt()).isEqualTo("메모 내용");
    assertThat(notice.adminUrl()).isEqualTo("https://api.example.com/admin/talk/posts/post-1");
    assertThat(notice.toString()).doesNotContain("reporter-1");
  }

  @Test
  @DisplayName("댓글 신고는 댓글 본문 일부와 댓글이 달린 글 링크를 담는다")
  void onReported_comment_buildsNotice() {
    when(talkReportRepository.findById("report-2")).thenReturn(Optional.of(report(TalkReportTargetType.COMMENT, "comment-1", "post-1")));
    TalkPost post = new TalkPost();
    post.setTitle("버스 타기");
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));
    TalkComment comment = new TalkComment();
    comment.setBody("댓글 본문");
    when(talkCommentRepository.findById("comment-1")).thenReturn(Optional.of(comment));

    talkReportMailListener.onReported(new TalkReportedEvent("report-2"));

    TalkReportNotice notice = captureNotice();
    assertThat(notice.targetType()).isEqualTo("댓글");
    assertThat(notice.excerpt()).isEqualTo("댓글 본문");
    assertThat(notice.adminUrl()).endsWith("/admin/talk/posts/post-1");
  }

  @Test
  @DisplayName("메일 발송이 실패해도 예외를 밖으로 던지지 않는다")
  void mailFailure_doesNotPropagate() {
    when(talkReportRepository.findById("report-1")).thenReturn(Optional.of(report(TalkReportTargetType.POST, "post-1", "post-1")));
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(new TalkPost()));
    doThrow(new IllegalStateException("boom")).when(talkReportMailer).sendReportNotice(any());

    assertThatCode(() -> talkReportMailListener.onReported(new TalkReportedEvent("report-1")))
      .doesNotThrowAnyException();
  }

  @Test
  @DisplayName("신고 기록을 찾지 못하면 메일을 보내지 않는다")
  void missingReport_sendsNothing() {
    when(talkReportRepository.findById("gone")).thenReturn(Optional.empty());

    talkReportMailListener.onReported(new TalkReportedEvent("gone"));

    verify(talkReportMailer, never()).sendReportNotice(any());
  }

  private TalkReportNotice captureNotice() {
    ArgumentCaptor<TalkReportNotice> captor = ArgumentCaptor.forClass(TalkReportNotice.class);
    verify(talkReportMailer).sendReportNotice(captor.capture());
    return captor.getValue();
  }

  private TalkReport report(TalkReportTargetType targetType, String targetId, String postId) {
    TalkReport report = new TalkReport();
    report.setId("report-1");
    report.setTargetType(targetType);
    report.setTargetId(targetId);
    report.setPostId(postId);
    report.setReporterMemberId("reporter-1");
    report.setReason(TalkReportReason.OFFENSIVE);
    return report;
  }
}
