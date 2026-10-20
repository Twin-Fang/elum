package com.chuseok22.elumserver.talk.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.talk.application.dto.request.TalkBlockRequest;
import com.chuseok22.elumserver.talk.application.dto.request.TalkReportRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkBlockResponse;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.core.TalkReportReason;
import com.chuseok22.elumserver.talk.core.TalkReportTargetType;
import com.chuseok22.elumserver.talk.core.event.TalkReportedEvent;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkBlock;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkComment;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkReport;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkBlockRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkCommentRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkReportRepository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.util.ReflectionTestUtils;

/// 신고 중복·자동 숨김 없음·이벤트, 차단 자기 자신·멱등·목록을 막는다.
@ExtendWith(MockitoExtension.class)
class TalkModerationServiceTest {

  private static final Caller REPORTER = Caller.guardian("reporter-1");

  @Mock
  private TalkReportRepository talkReportRepository;
  @Mock
  private TalkBlockRepository talkBlockRepository;
  @Mock
  private TalkPostRepository talkPostRepository;
  @Mock
  private TalkCommentRepository talkCommentRepository;
  @Mock
  private MemberService memberService;
  @Mock
  private ApplicationEventPublisher eventPublisher;

  private TalkModerationService talkModerationService;

  @BeforeEach
  void setUp() {
    talkModerationService = new TalkModerationService(talkReportRepository, talkBlockRepository, talkPostRepository,
      talkCommentRepository, memberService, eventPublisher);
  }

  @Test
  @DisplayName("같은 신고자가 같은 글을 또 신고하면 TALK_REPORT_DUPLICATED")
  void report_duplicate_throws() {
    stubVisiblePost("post-1", "author-1");
    when(talkReportRepository.existsByTargetTypeAndTargetIdAndReporterMemberId(
      TalkReportTargetType.POST, "post-1", "reporter-1")).thenReturn(true);

    assertThatThrownBy(() -> talkModerationService.report(REPORTER, postReport("post-1")))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_REPORT_DUPLICATED));
    verify(talkReportRepository, never()).saveAndFlush(any());
    verify(eventPublisher, never()).publishEvent(any(Object.class));
  }

  @Test
  @DisplayName("동시에 같은 신고가 겹쳐 유니크에 걸려도 TALK_REPORT_DUPLICATED")
  void report_uniqueViolation_throwsDuplicated() {
    stubVisiblePost("post-1", "author-1");
    when(talkReportRepository.saveAndFlush(any(TalkReport.class))).thenThrow(new DataIntegrityViolationException("dup"));

    assertThatThrownBy(() -> talkModerationService.report(REPORTER, postReport("post-1")))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_REPORT_DUPLICATED));
    verify(eventPublisher, never()).publishEvent(any(Object.class));
  }

  @Test
  @DisplayName("세 명이 신고해도 글은 그대로 보이고 어떤 상태 변경도 하지 않는다")
  void report_doesNotHidePost() {
    TalkPost post = stubVisiblePost("post-1", "author-1");
    stubSaveReport("report-1");

    for (String reporterId : List.of("reporter-1", "reporter-2", "reporter-3")) {
      talkModerationService.report(Caller.guardian(reporterId), postReport("post-1"));
    }

    assertThat(post.getStatus()).isEqualTo(TalkPostStatus.VISIBLE);
    verify(talkPostRepository, never()).save(any());
  }

  @Test
  @DisplayName("신고를 저장하면 신고 id 를 담은 이벤트를 내보낸다")
  void report_publishesEvent() {
    stubVisiblePost("post-1", "author-1");
    stubSaveReport("report-1");

    talkModerationService.report(REPORTER, postReport("post-1"));

    verify(eventPublisher).publishEvent(new TalkReportedEvent("report-1"));
  }

  @Test
  @DisplayName("댓글 신고는 댓글이 달린 글 id 를 함께 저장한다")
  void report_comment_storesPostId() {
    TalkComment comment = new TalkComment();
    comment.setPostId("post-9");
    comment.setAuthorMemberId("author-1");
    when(talkCommentRepository.findById("comment-1")).thenReturn(Optional.of(comment));
    stubSaveReport("report-2");

    talkModerationService.report(REPORTER, new TalkReportRequest("COMMENT", "comment-1", "OFFENSIVE"));

    ArgumentCaptor<TalkReport> captor = ArgumentCaptor.forClass(TalkReport.class);
    verify(talkReportRepository).saveAndFlush(captor.capture());
    assertThat(captor.getValue().getPostId()).isEqualTo("post-9");
    assertThat(captor.getValue().getTargetType()).isEqualTo(TalkReportTargetType.COMMENT);
    assertThat(captor.getValue().getReporterMemberId()).isEqualTo("reporter-1");
  }

  @Test
  @DisplayName("없는 글·잘못된 사유는 거절한다")
  void report_invalidTarget_throws() {
    when(talkPostRepository.findById("gone")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> talkModerationService.report(REPORTER, postReport("gone")))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_POST_NOT_FOUND));
    assertThatThrownBy(() -> talkModerationService.report(REPORTER, new TalkReportRequest("POST", "post-1", "NOPE")))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
  }

  @Test
  @DisplayName("자기 자신은 차단할 수 없다")
  void block_self_throws() {
    stubVisiblePost("post-1", "reporter-1");

    assertThatThrownBy(() -> talkModerationService.block(REPORTER, new TalkBlockRequest("post-1", null)))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_CANNOT_BLOCK_SELF));
    verify(talkBlockRepository, never()).saveAndFlush(any());
  }

  @Test
  @DisplayName("글과 댓글 중 정확히 하나만 주지 않으면 INVALID_INPUT_VALUE")
  void block_needsExactlyOneTarget() {
    assertThatThrownBy(() -> talkModerationService.block(REPORTER, new TalkBlockRequest(null, null)))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
    assertThatThrownBy(() -> talkModerationService.block(REPORTER, new TalkBlockRequest("post-1", "comment-1")))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
  }

  @Test
  @DisplayName("같은 보호자를 두 번 차단해도 한 번만 저장한다")
  void block_twice_idempotent() {
    stubVisiblePost("post-1", "author-1");
    when(talkBlockRepository.existsByBlockerMemberIdAndBlockedMemberId("reporter-1", "author-1"))
      .thenReturn(false, true);

    talkModerationService.block(REPORTER, new TalkBlockRequest("post-1", null));
    talkModerationService.block(REPORTER, new TalkBlockRequest("post-1", null));

    ArgumentCaptor<TalkBlock> captor = ArgumentCaptor.forClass(TalkBlock.class);
    verify(talkBlockRepository).saveAndFlush(captor.capture());
    assertThat(captor.getValue().getBlockerMemberId()).isEqualTo("reporter-1");
    assertThat(captor.getValue().getBlockedMemberId()).isEqualTo("author-1");
  }

  @Test
  @DisplayName("동시에 차단이 겹쳐 유니크에 걸려도 조용히 넘어간다")
  void block_uniqueViolation_isIgnored() {
    stubVisiblePost("post-1", "author-1");
    when(talkBlockRepository.saveAndFlush(any(TalkBlock.class))).thenThrow(new DataIntegrityViolationException("dup"));

    talkModerationService.block(REPORTER, new TalkBlockRequest("post-1", null));
  }

  @Test
  @DisplayName("댓글로도 글쓴이를 찾아 차단한다")
  void block_byComment_blocksCommentAuthor() {
    TalkComment comment = new TalkComment();
    comment.setPostId("post-1");
    comment.setAuthorMemberId("author-2");
    when(talkCommentRepository.findById("comment-1")).thenReturn(Optional.of(comment));

    talkModerationService.block(REPORTER, new TalkBlockRequest(null, "comment-1"));

    ArgumentCaptor<TalkBlock> captor = ArgumentCaptor.forClass(TalkBlock.class);
    verify(talkBlockRepository).saveAndFlush(captor.capture());
    assertThat(captor.getValue().getBlockedMemberId()).isEqualTo("author-2");
  }

  @Test
  @DisplayName("차단 해제는 내 차단만, 남의 차단 id 는 INVALID_INPUT_VALUE")
  void unblock_onlyOwn() {
    TalkBlock mine = block("block-1", "reporter-1", "author-1");
    TalkBlock others = block("block-2", "someone-else", "author-1");
    when(talkBlockRepository.findById("block-1")).thenReturn(Optional.of(mine));
    when(talkBlockRepository.findById("block-2")).thenReturn(Optional.of(others));

    talkModerationService.unblock(REPORTER, "block-1");
    verify(talkBlockRepository).delete(mine);

    assertThatThrownBy(() -> talkModerationService.unblock(REPORTER, "block-2"))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
    verify(talkBlockRepository, never()).delete(others);
  }

  @Test
  @DisplayName("차단 목록은 차단 id·닉네임·시각만 돌려준다")
  void blocks_listsNicknames() {
    TalkBlock first = block("block-1", "reporter-1", "author-1");
    ReflectionTestUtils.setField(first, "createdAt", LocalDateTime.of(2026, 10, 20, 9, 0));
    when(talkBlockRepository.findByBlockerMemberIdOrderByCreatedAtDesc("reporter-1")).thenReturn(List.of(first));
    when(memberService.nicknamesOf(anyCollection())).thenReturn(Map.of("author-1", "이웃"));

    List<TalkBlockResponse> responses = talkModerationService.blocks(REPORTER);

    assertThat(responses).hasSize(1);
    assertThat(responses.get(0).blockId()).isEqualTo("block-1");
    assertThat(responses.get(0).nickname()).isEqualTo("이웃");
    assertThat(responses.get(0).createdAt()).isEqualTo(LocalDateTime.of(2026, 10, 20, 9, 0));
  }

  private TalkReportRequest postReport(String postId) {
    return new TalkReportRequest("POST", postId, "OFFENSIVE");
  }

  private TalkPost stubVisiblePost(String postId, String authorMemberId) {
    TalkPost post = new TalkPost();
    post.setId(postId);
    post.setAuthorMemberId(authorMemberId);
    post.setStatus(TalkPostStatus.VISIBLE);
    when(talkPostRepository.findById(postId)).thenReturn(Optional.of(post));
    return post;
  }

  private void stubSaveReport(String reportId) {
    when(talkReportRepository.saveAndFlush(any(TalkReport.class))).thenAnswer(invocation -> {
      TalkReport saved = invocation.getArgument(0);
      saved.setId(reportId);
      return saved;
    });
  }

  private TalkBlock block(String id, String blockerMemberId, String blockedMemberId) {
    TalkBlock block = new TalkBlock();
    block.setId(id);
    block.setBlockerMemberId(blockerMemberId);
    block.setBlockedMemberId(blockedMemberId);
    return block;
  }
}
