package com.chuseok22.elumserver.talk.application.listener;

import com.chuseok22.elumserver.common.infrastructure.config.AsyncConfig;
import com.chuseok22.elumserver.common.infrastructure.properties.TalkProperties;
import com.chuseok22.elumserver.talk.core.event.TalkReportedEvent;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkComment;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkReport;
import com.chuseok22.elumserver.talk.infrastructure.mail.TalkReportMailer;
import com.chuseok22.elumserver.talk.infrastructure.mail.TalkReportNotice;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkCommentRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkReportRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * 신고 이벤트 수신: 신고 메일 내용 조립 > 발송
 * 커밋 뒤 + 별도 스레드, 실패는 로그만 (신고 요청에 영향 없음), 신고자 정보는 메일에 넣지 않음
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class TalkReportMailListener {

  private static final String ADMIN_POST_PATH = "/admin/talk/posts/";

  private final TalkReportRepository talkReportRepository;
  private final TalkPostRepository talkPostRepository;
  private final TalkCommentRepository talkCommentRepository;
  private final TalkReportMailer talkReportMailer;
  private final TalkProperties talkProperties;

  @Async(AsyncConfig.NOTIFICATION_EXECUTOR)
  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  public void onReported(TalkReportedEvent event) {
    try {
      TalkReport report = talkReportRepository.findById(event.reportId()).orElse(null);
      if (report == null) {
        log.warn("[talk report mail] skipped : report not found {}", event.reportId());
        return;
      }
      talkReportMailer.sendReportNotice(toNotice(report));
    } catch (RuntimeException e) {
      log.warn("[talk report mail] failed : {}", event.reportId());
    }
  }

  // 신고 > 메일 내용 (글 제목, 댓글 본문 또는 글 메모 일부, 관리자 링크)
  private TalkReportNotice toNotice(TalkReport report) {
    TalkPost post = talkPostRepository.findById(report.getPostId()).orElse(null);
    String excerpt = switch (report.getTargetType()) {
      case COMMENT -> talkCommentRepository.findById(report.getTargetId()).map(TalkComment::getBody).orElse("");
      case POST -> post == null || post.getNote() == null ? "" : post.getNote();
    };
    return new TalkReportNotice(report.getId(), report.getTargetType().getLabel(), report.getReason().getLabel(),
      post == null ? "" : post.getTitle(), excerpt, adminPostUrl(report.getPostId()));
  }

  // {기준 주소}/admin/talk/posts/{postId} (기준 주소 끝 슬래시 제거)
  private String adminPostUrl(String postId) {
    String baseUrl = talkProperties.adminBaseUrl().replaceAll("/+$", "");
    return baseUrl + ADMIN_POST_PATH + postId;
  }
}
