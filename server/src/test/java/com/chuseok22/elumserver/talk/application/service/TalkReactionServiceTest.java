package com.chuseok22.elumserver.talk.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.member.core.NicknamePolicy;
import com.chuseok22.elumserver.notification.core.event.TalkPostCommentedEvent;
import com.chuseok22.elumserver.routine.application.service.RoutineShareService;
import com.chuseok22.elumserver.talk.application.dto.request.TalkCommentRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkCommentPageResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkCommentResponse;
import com.chuseok22.elumserver.talk.core.TalkCommentStatus;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkBlock;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkComment;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkHelpful;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkBlockRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkCommentRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkHelpfulRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
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

/// 도움이 됐어요 중복 집계, 규칙 미동의·내려간 글에 댓글, 남의 댓글 지우기, 차단한 보호자 댓글 노출을 막는다.
@ExtendWith(MockitoExtension.class)
class TalkReactionServiceTest {

  private static final Caller VIEWER = Caller.guardian("viewer-1");
  private static final LocalDateTime BASE_TIME = LocalDateTime.of(2026, 10, 20, 9, 0);

  @Mock
  private RoutineShareService routineShareService;
  @Mock
  private TalkPostRepository talkPostRepository;
  @Mock
  private TalkHelpfulRepository talkHelpfulRepository;
  @Mock
  private TalkCommentRepository talkCommentRepository;
  @Mock
  private TalkBlockRepository talkBlockRepository;
  @Mock
  private MemberService memberService;
  @Mock
  private ApplicationEventPublisher eventPublisher;

  private TalkReactionService talkReactionService;

  @BeforeEach
  void setUp() {
    talkReactionService = new TalkReactionService(postAccess(), talkPostRepository, talkHelpfulRepository,
      talkCommentRepository, talkBlockRepository, memberService, new NicknamePolicy(), eventPublisher);
  }

  @Test
  @DisplayName("같은 글에 도움이 됐어요를 두 번 눌러도 한 번만 센다")
  void markHelpful_twice_countsOnce() {
    stubVisiblePost("post-1");
    when(talkHelpfulRepository.existsByPostIdAndMemberId("post-1", "viewer-1")).thenReturn(false, true);

    talkReactionService.markHelpful(VIEWER, "post-1");
    talkReactionService.markHelpful(VIEWER, "post-1");

    verify(talkHelpfulRepository, times(1)).saveAndFlush(any(TalkHelpful.class));
    verify(talkPostRepository, times(1)).increaseHelpfulCount("post-1");
  }

  @Test
  @DisplayName("동시에 눌려 유니크 충돌이 나도 오류 없이 한 번만 센다")
  void markHelpful_uniqueConflict_isIgnoredWithoutCounting() {
    stubVisiblePost("post-1");
    when(talkHelpfulRepository.existsByPostIdAndMemberId("post-1", "viewer-1")).thenReturn(false);
    when(talkHelpfulRepository.saveAndFlush(any(TalkHelpful.class))).thenThrow(new DataIntegrityViolationException("dup"));

    talkReactionService.markHelpful(VIEWER, "post-1");

    verify(talkPostRepository, never()).increaseHelpfulCount(anyString());
  }

  @Test
  @DisplayName("내려간 글에는 도움이 됐어요를 누를 수 없다")
  void markHelpful_onDeletedPost_throwsNotFound() {
    TalkPost deleted = post("post-1", "author-1");
    deleted.setStatus(TalkPostStatus.DELETED);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(deleted));

    assertThatThrownBy(() -> talkReactionService.markHelpful(VIEWER, "post-1"))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_POST_NOT_FOUND));
    verify(talkHelpfulRepository, never()).saveAndFlush(any());
  }

  @Test
  @DisplayName("내가 차단한 글쓴이의 글에는 도움이 됐어요를 누를 수 없다")
  void markHelpful_onBlockedAuthorPost_throwsNotFound() {
    stubVisiblePost("post-1");
    blockAuthor("author-1");

    assertThatThrownBy(() -> talkReactionService.markHelpful(VIEWER, "post-1"))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_POST_NOT_FOUND));
    verify(talkHelpfulRepository, never()).saveAndFlush(any());
    verify(talkPostRepository, never()).increaseHelpfulCount(anyString());
  }

  @Test
  @DisplayName("누른 적 없는 도움이 됐어요를 취소해도 아무 일도 없고 수가 줄지 않는다")
  void unmarkHelpful_withoutMark_noop() {
    stubVisiblePost("post-1");
    when(talkHelpfulRepository.deleteByPostIdAndMemberId("post-1", "viewer-1")).thenReturn(0);

    talkReactionService.unmarkHelpful(VIEWER, "post-1");

    verify(talkPostRepository, never()).decreaseHelpfulCount(anyString());
  }

  @Test
  @DisplayName("누른 도움이 됐어요를 취소하면 수가 하나 준다")
  void unmarkHelpful_withMark_decreasesOnce() {
    stubVisiblePost("post-1");
    when(talkHelpfulRepository.deleteByPostIdAndMemberId("post-1", "viewer-1")).thenReturn(1);

    talkReactionService.unmarkHelpful(VIEWER, "post-1");

    verify(talkPostRepository, times(1)).decreaseHelpfulCount("post-1");
  }

  @Test
  @DisplayName("이용 규칙에 동의하지 않았으면 댓글을 쓸 수 없다")
  void addComment_notAgreed_throws() {
    when(memberService.hasAgreedTalkRules("viewer-1")).thenReturn(false);

    assertThatThrownBy(() -> talkReactionService.addComment(VIEWER, "post-1", new TalkCommentRequest("좋아요")))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_RULES_NOT_AGREED));
    verify(talkCommentRepository, never()).save(any());
  }

  @Test
  @DisplayName("빈 댓글은 INVALID_INPUT_VALUE 로 거절한다")
  void addComment_blank_throwsInvalidInput() {
    when(memberService.hasAgreedTalkRules("viewer-1")).thenReturn(true);

    assertThatThrownBy(() -> talkReactionService.addComment(VIEWER, "post-1", new TalkCommentRequest("  \n ")))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));
    verify(talkCommentRepository, never()).save(any());
  }

  @Test
  @DisplayName("300자가 넘는 댓글은 TALK_TEXT_TOO_LONG 으로 거절한다")
  void addComment_over300_throwsTooLong() {
    when(memberService.hasAgreedTalkRules("viewer-1")).thenReturn(true);

    assertThatThrownBy(() -> talkReactionService.addComment(VIEWER, "post-1", new TalkCommentRequest("가".repeat(301))))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_TEXT_TOO_LONG));
    verify(talkCommentRepository, never()).save(any());
  }

  @Test
  @DisplayName("금칙어가 든 댓글은 TALK_TEXT_NOT_ALLOWED 로 거절한다")
  void addComment_blockedWord_throwsNotAllowed() {
    when(memberService.hasAgreedTalkRules("viewer-1")).thenReturn(true);
    NicknamePolicy rejectingPolicy = org.mockito.Mockito.mock(NicknamePolicy.class);
    when(rejectingPolicy.containsBlockedWord("나쁜말")).thenReturn(true);
    TalkReactionService service = new TalkReactionService(postAccess(), talkPostRepository, talkHelpfulRepository,
      talkCommentRepository, talkBlockRepository, memberService, rejectingPolicy, eventPublisher);

    assertThatThrownBy(() -> service.addComment(VIEWER, "post-1", new TalkCommentRequest("나쁜말")))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_TEXT_NOT_ALLOWED));
    verify(talkCommentRepository, never()).save(any());
  }

  @Test
  @DisplayName("내가 차단한 글쓴이의 글에는 댓글을 쓸 수 없고 댓글 수도 늘지 않는다")
  void addComment_onBlockedAuthorPost_throwsNotFound() {
    when(memberService.hasAgreedTalkRules("viewer-1")).thenReturn(true);
    stubVisiblePost("post-1");
    blockAuthor("author-1");

    assertThatThrownBy(() -> talkReactionService.addComment(VIEWER, "post-1", new TalkCommentRequest("좋아요")))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_POST_NOT_FOUND));
    verify(talkCommentRepository, never()).save(any());
    verify(talkPostRepository, never()).increaseCommentCount(anyString());
  }

  @Test
  @DisplayName("정지 회원의 글에는 댓글을 쓸 수 없다")
  void addComment_onSuspendedAuthorPost_throwsNotFound() {
    when(memberService.hasAgreedTalkRules("viewer-1")).thenReturn(true);
    stubVisiblePost("post-1");
    when(memberService.suspendedAmong(anyCollection())).thenReturn(Set.of("author-1"));

    assertThatThrownBy(() -> talkReactionService.addComment(VIEWER, "post-1", new TalkCommentRequest("좋아요")))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_POST_NOT_FOUND));
    verify(talkCommentRepository, never()).save(any());
  }

  @Test
  @DisplayName("내려간 글에는 댓글을 쓸 수 없고 댓글 수도 늘지 않는다")
  void addComment_onDeletedPost_throwsNotFound() {
    when(memberService.hasAgreedTalkRules("viewer-1")).thenReturn(true);
    TalkPost deleted = post("post-1", "author-1");
    deleted.setStatus(TalkPostStatus.DELETED);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(deleted));

    assertThatThrownBy(() -> talkReactionService.addComment(VIEWER, "post-1", new TalkCommentRequest("좋아요")))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_POST_NOT_FOUND));
    verify(talkCommentRepository, never()).save(any());
    verify(talkPostRepository, never()).increaseCommentCount(anyString());
  }

  @Test
  @DisplayName("댓글을 쓰면 앞뒤 공백을 지워 저장하고 댓글 수가 하나 는다")
  void addComment_savesTrimmedBodyAndIncreasesCount() {
    when(memberService.hasAgreedTalkRules("viewer-1")).thenReturn(true);
    stubVisiblePost("post-1");
    when(talkCommentRepository.save(any(TalkComment.class))).thenAnswer(invocation -> {
      TalkComment saved = invocation.getArgument(0);
      saved.setId("comment-1");
      ReflectionTestUtils.setField(saved, "createdAt", BASE_TIME);
      return saved;
    });
    when(memberService.nicknamesOf(anyCollection())).thenReturn(Map.of("viewer-1", "내닉네임"));

    TalkCommentResponse response = talkReactionService.addComment(VIEWER, "post-1", new TalkCommentRequest("  좋아요 "));

    ArgumentCaptor<TalkComment> captor = ArgumentCaptor.forClass(TalkComment.class);
    verify(talkCommentRepository).save(captor.capture());
    assertThat(captor.getValue().getBody()).isEqualTo("좋아요");
    assertThat(captor.getValue().getAuthorMemberId()).isEqualTo("viewer-1");
    assertThat(captor.getValue().getPostId()).isEqualTo("post-1");
    verify(talkPostRepository).increaseCommentCount("post-1");
    assertThat(response.id()).isEqualTo("comment-1");
    assertThat(response.isMine()).isTrue();
    assertThat(response.authorNickname()).isEqualTo("내닉네임");
  }

  @Test
  @DisplayName("댓글을 쓰면 글쓴이·행동한 사람·글 제목을 담은 알림 이벤트를 내보낸다")
  void addComment_publishesEvent() {
    when(memberService.hasAgreedTalkRules("viewer-1")).thenReturn(true);
    TalkPost post = post("post-1", "author-1");
    post.setTitle("버스 타기");
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));
    when(talkCommentRepository.save(any(TalkComment.class))).thenAnswer(invocation -> invocation.getArgument(0));
    when(memberService.nicknamesOf(anyCollection())).thenReturn(Map.of());

    talkReactionService.addComment(VIEWER, "post-1", new TalkCommentRequest("좋아요"));

    verify(eventPublisher).publishEvent(new TalkPostCommentedEvent("post-1", "author-1", "viewer-1", "버스 타기"));
  }

  @Test
  @DisplayName("글쓴이가 댓글 쓴 보호자를 차단했으면 댓글은 저장하되 알림 이벤트는 내보내지 않는다")
  void addComment_authorBlockedActor_publishesNoEvent() {
    when(memberService.hasAgreedTalkRules("viewer-1")).thenReturn(true);
    TalkPost post = post("post-1", "author-1");
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(post));
    when(talkCommentRepository.save(any(TalkComment.class))).thenAnswer(invocation -> invocation.getArgument(0));
    when(memberService.nicknamesOf(anyCollection())).thenReturn(Map.of());
    when(talkBlockRepository.existsByBlockerMemberIdAndBlockedMemberId("author-1", "viewer-1")).thenReturn(true);

    talkReactionService.addComment(VIEWER, "post-1", new TalkCommentRequest("좋아요"));

    verify(talkCommentRepository).save(any(TalkComment.class));
    verify(eventPublisher, never()).publishEvent(any(Object.class));
  }

  @Test
  @DisplayName("댓글 규칙에 걸려 거절되면 알림 이벤트를 내보내지 않는다")
  void addComment_rejected_publishesNothing() {
    when(memberService.hasAgreedTalkRules("viewer-1")).thenReturn(false);

    assertThatThrownBy(() -> talkReactionService.addComment(VIEWER, "post-1", new TalkCommentRequest("좋아요")))
      .isInstanceOf(CustomException.class);

    verify(eventPublisher, never()).publishEvent(any(Object.class));
  }

  @Test
  @DisplayName("남의 댓글은 지울 수 없다")
  void deleteComment_byOther_throwsNotAuthor() {
    TalkComment comment = comment("comment-1", "post-1", "other-1", BASE_TIME);
    when(talkCommentRepository.findById("comment-1")).thenReturn(Optional.of(comment));

    assertThatThrownBy(() -> talkReactionService.deleteComment(VIEWER, "comment-1"))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_NOT_AUTHOR));
    assertThat(comment.getStatus()).isEqualTo(TalkCommentStatus.VISIBLE);
    verify(talkPostRepository, never()).decreaseCommentCount(anyString());
  }

  @Test
  @DisplayName("이미 지운 댓글이나 없는 댓글은 TALK_COMMENT_NOT_FOUND 이다")
  void deleteComment_missingOrDeleted_throwsNotFound() {
    TalkComment deleted = comment("comment-1", "post-1", "viewer-1", BASE_TIME);
    deleted.setStatus(TalkCommentStatus.DELETED);
    when(talkCommentRepository.findById("comment-1")).thenReturn(Optional.of(deleted));
    when(talkCommentRepository.findById("missing")).thenReturn(Optional.empty());

    for (String commentId : List.of("comment-1", "missing")) {
      assertThatThrownBy(() -> talkReactionService.deleteComment(VIEWER, commentId))
        .isInstanceOfSatisfying(CustomException.class,
          e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_COMMENT_NOT_FOUND));
    }
    verify(talkPostRepository, never()).decreaseCommentCount(anyString());
  }

  @Test
  @DisplayName("내 댓글을 지우면 DELETED 로 바꾸고 댓글 수가 하나 준다")
  void deleteComment_byAuthor_marksDeletedAndDecreasesCount() {
    TalkComment comment = comment("comment-1", "post-1", "viewer-1", BASE_TIME);
    when(talkCommentRepository.findById("comment-1")).thenReturn(Optional.of(comment));
    when(talkCommentRepository.updateStatusIfVisible("comment-1", TalkCommentStatus.DELETED, TalkCommentStatus.VISIBLE))
      .thenReturn(1);

    talkReactionService.deleteComment(VIEWER, "comment-1");

    verify(talkPostRepository).decreaseCommentCount("post-1");
  }

  @Test
  @DisplayName("동시에 두 번 지워져 먼저 바뀐 뒤면 댓글 수를 줄이지 않는다")
  void deleteComment_alreadyChangedByConcurrentDelete_doesNotDecrease() {
    TalkComment comment = comment("comment-1", "post-1", "viewer-1", BASE_TIME);
    when(talkCommentRepository.findById("comment-1")).thenReturn(Optional.of(comment));
    when(talkCommentRepository.updateStatusIfVisible("comment-1", TalkCommentStatus.DELETED, TalkCommentStatus.VISIBLE))
      .thenReturn(0);

    talkReactionService.deleteComment(VIEWER, "comment-1");

    verify(talkPostRepository, never()).decreaseCommentCount(anyString());
  }

  @Test
  @DisplayName("글을 올린 보호자의 댓글만 글쓴이로 표시한다")
  void comments_markPostAuthor() {
    stubVisiblePost("post-1");
    when(talkBlockRepository.findByBlockerMemberId("viewer-1")).thenReturn(List.of());
    when(memberService.suspendedAmong(anyCollection())).thenReturn(Set.of());
    when(memberService.nicknamesOf(anyCollection())).thenReturn(Map.of());
    when(talkCommentRepository.findCommentPage(eq("post-1"), eq(TalkCommentStatus.VISIBLE), anyString(), any(), anyString(), any()))
      .thenReturn(List.of(
        comment("c1", "post-1", "author-1", BASE_TIME),
        comment("c2", "post-1", "viewer-1", BASE_TIME.plusMinutes(1))));

    TalkCommentPageResponse page = talkReactionService.comments(VIEWER, "post-1", null, null);

    assertThat(page.items()).extracting(TalkCommentResponse::isPostAuthor).containsExactly(true, false);
  }

  @Test
  @DisplayName("차단한 보호자와 정지 회원의 댓글은 빠지고 내 댓글은 남는다")
  void comments_excludeBlockedAuthors() {
    stubVisiblePost("post-1");
    TalkBlock block = new TalkBlock();
    block.setBlockerMemberId("viewer-1");
    block.setBlockedMemberId("author-blocked");
    when(talkBlockRepository.findByBlockerMemberId("viewer-1")).thenReturn(List.of(block));
    when(memberService.suspendedAmong(anyCollection())).thenReturn(Set.of("author-suspended"));
    when(memberService.nicknamesOf(anyCollection())).thenReturn(Map.of("author-ok", "이웃", "viewer-1", "나"));
    when(talkCommentRepository.findCommentPage(eq("post-1"), eq(TalkCommentStatus.VISIBLE), anyString(), any(), anyString(), any()))
      .thenReturn(List.of(
        comment("c1", "post-1", "author-blocked", BASE_TIME),
        comment("c2", "post-1", "author-suspended", BASE_TIME.plusMinutes(1)),
        comment("c3", "post-1", "author-ok", BASE_TIME.plusMinutes(2)),
        comment("c4", "post-1", "viewer-1", BASE_TIME.plusMinutes(3))));

    TalkCommentPageResponse page = talkReactionService.comments(VIEWER, "post-1", null, null);

    assertThat(page.items()).extracting(TalkCommentResponse::id).containsExactly("c3", "c4");
    assertThat(page.items()).extracting(TalkCommentResponse::isMine).containsExactly(false, true);
    assertThat(page.items().get(0).authorNickname()).isEqualTo("이웃");
    assertThat(page.nextCursor()).isNull();
  }

  @Test
  @DisplayName("관리자가 가린 내 댓글은 isHidden 으로 표시하고 본문은 비워서 준다")
  void comments_hiddenOwnComment_marksHiddenAndBlanksBody() {
    stubScanDependencies();
    TalkComment hidden = comment("c1", "post-1", "viewer-1", BASE_TIME);
    hidden.setStatus(TalkCommentStatus.HIDDEN_BY_ADMIN);
    when(talkCommentRepository.findCommentPage(eq("post-1"), eq(TalkCommentStatus.VISIBLE), eq("viewer-1"), any(), anyString(), any()))
      .thenReturn(List.of(hidden, comment("c2", "post-1", "author-ok", BASE_TIME.plusMinutes(1))));

    TalkCommentPageResponse page = talkReactionService.comments(VIEWER, "post-1", null, null);

    assertThat(page.items()).extracting(TalkCommentResponse::isHidden).containsExactly(true, false);
    assertThat(page.items().get(0).body()).isEmpty();
    assertThat(page.items().get(1).body()).isEqualTo("내용 c2");
  }

  @Test
  @DisplayName("한 쪽보다 많으면 size 만큼 자르고 마지막 댓글 위치를 nextCursor 로 준다")
  void comments_overOnePage_returnsNextCursor() {
    stubVisiblePost("post-1");
    when(talkBlockRepository.findByBlockerMemberId("viewer-1")).thenReturn(List.of());
    when(memberService.suspendedAmong(anyCollection())).thenReturn(Set.of());
    when(memberService.nicknamesOf(anyCollection())).thenReturn(Map.of());
    when(talkCommentRepository.findCommentPage(eq("post-1"), eq(TalkCommentStatus.VISIBLE), anyString(), any(), anyString(), any()))
      .thenReturn(List.of(
        comment("c1", "post-1", "author-ok", BASE_TIME),
        comment("c2", "post-1", "author-ok", BASE_TIME.plusMinutes(1)),
        comment("c3", "post-1", "author-ok", BASE_TIME.plusMinutes(2))));

    TalkCommentPageResponse page = talkReactionService.comments(VIEWER, "post-1", null, 2);

    assertThat(page.items()).extracting(TalkCommentResponse::id).containsExactly("c1", "c2");
    assertThat(page.nextCursor()).isEqualTo(BASE_TIME.plusMinutes(1) + "|c2");
  }

  @Test
  @DisplayName("첫 묶음이 전부 차단이면 이어 읽고, 이어 읽는 위치는 방금 읽은 마지막 댓글이다")
  void comments_firstBatchAllBlocked_readsNextBatchFromLastScannedRow() {
    stubScanDependencies();
    List<TalkComment> blockedBatch = List.of(
      comment("c1", "post-1", "author-blocked", BASE_TIME),
      comment("c2", "post-1", "author-blocked", BASE_TIME.plusMinutes(1)),
      comment("c3", "post-1", "author-blocked", BASE_TIME.plusMinutes(2)));
    when(talkCommentRepository.findCommentPage(eq("post-1"), eq(TalkCommentStatus.VISIBLE), anyString(), any(), anyString(), any()))
      .thenReturn(blockedBatch, List.of(comment("c4", "post-1", "author-ok", BASE_TIME.plusMinutes(3))));

    TalkCommentPageResponse page = talkReactionService.comments(VIEWER, "post-1", null, 2);

    ArgumentCaptor<LocalDateTime> createdAts = ArgumentCaptor.forClass(LocalDateTime.class);
    ArgumentCaptor<String> ids = ArgumentCaptor.forClass(String.class);
    verify(talkCommentRepository, times(2))
      .findCommentPage(eq("post-1"), eq(TalkCommentStatus.VISIBLE), anyString(), createdAts.capture(), ids.capture(), any());
    assertThat(createdAts.getAllValues().get(1)).isEqualTo(BASE_TIME.plusMinutes(2));
    assertThat(ids.getAllValues().get(1)).isEqualTo("c3");
    assertThat(page.items()).extracting(TalkCommentResponse::id).containsExactly("c4");
    assertThat(page.nextCursor()).isNull();
  }

  @Test
  @DisplayName("다섯 번 읽어도 전부 차단이면 빈 쪽과 함께 읽은 마지막 위치로 nextCursor 를 준다")
  void comments_maxScanRoundsReached_returnsCursorAtScanPosition() {
    stubScanDependencies();
    when(talkCommentRepository.findCommentPage(eq("post-1"), eq(TalkCommentStatus.VISIBLE), anyString(), any(), anyString(), any()))
      .thenReturn(blockedBatch(0), blockedBatch(3), blockedBatch(6), blockedBatch(9), blockedBatch(12));

    TalkCommentPageResponse page = talkReactionService.comments(VIEWER, "post-1", null, 2);

    verify(talkCommentRepository, times(5))
      .findCommentPage(eq("post-1"), eq(TalkCommentStatus.VISIBLE), anyString(), any(), anyString(), any());
    assertThat(page.items()).isEmpty();
    assertThat(page.nextCursor()).isEqualTo(BASE_TIME.plusMinutes(14) + "|c14");
  }

  @Test
  @DisplayName("형식이 틀린 cursor 는 첫 쪽으로 본다")
  void comments_malformedCursor_readsFirstPage() {
    stubScanDependencies();
    when(talkCommentRepository.findCommentPage(eq("post-1"), eq(TalkCommentStatus.VISIBLE), anyString(), any(), anyString(), any()))
      .thenReturn(List.of());

    talkReactionService.comments(VIEWER, "post-1", "garbage", null);

    ArgumentCaptor<LocalDateTime> createdAt = ArgumentCaptor.forClass(LocalDateTime.class);
    verify(talkCommentRepository).findCommentPage(
      eq("post-1"), eq(TalkCommentStatus.VISIBLE), anyString(), createdAt.capture(), eq(""), any());
    assertThat(createdAt.getValue()).isEqualTo(LocalDateTime.of(1970, 1, 1, 0, 0));
  }

  @Test
  @DisplayName("내려간 글의 댓글은 볼 수 없다")
  void comments_onDeletedPost_throwsNotFound() {
    TalkPost deleted = post("post-1", "author-1");
    deleted.setStatus(TalkPostStatus.DELETED);
    when(talkPostRepository.findById("post-1")).thenReturn(Optional.of(deleted));

    assertThatThrownBy(() -> talkReactionService.comments(VIEWER, "post-1", null, null))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.TALK_POST_NOT_FOUND));
  }

  // 차단한 보호자 1명(author-blocked), 정지 회원 없음
  private void stubScanDependencies() {
    stubVisiblePost("post-1");
    TalkBlock block = new TalkBlock();
    block.setBlockerMemberId("viewer-1");
    block.setBlockedMemberId("author-blocked");
    when(talkBlockRepository.findByBlockerMemberId("viewer-1")).thenReturn(List.of(block));
    lenient().when(memberService.suspendedAmong(anyCollection())).thenReturn(Set.of());
    lenient().when(memberService.nicknamesOf(anyCollection())).thenReturn(Map.of());
  }

  // 차단 작성자 댓글 3건 (c{firstIndex}..c{firstIndex+2}, 1분 간격)
  private static List<TalkComment> blockedBatch(int firstIndex) {
    return List.of(
      comment("c" + firstIndex, "post-1", "author-blocked", BASE_TIME.plusMinutes(firstIndex)),
      comment("c" + (firstIndex + 1), "post-1", "author-blocked", BASE_TIME.plusMinutes(firstIndex + 1)),
      comment("c" + (firstIndex + 2), "post-1", "author-blocked", BASE_TIME.plusMinutes(firstIndex + 2)));
  }

  // 내가 차단한 글쓴이 1명
  private void blockAuthor(String blockedMemberId) {
    TalkBlock block = new TalkBlock();
    block.setBlockerMemberId("viewer-1");
    block.setBlockedMemberId(blockedMemberId);
    when(talkBlockRepository.findByBlockerMemberId("viewer-1")).thenReturn(List.of(block));
  }

  // 같은 목 저장소로 만든 실제 접근 규칙
  private TalkPostAccess postAccess() {
    return new TalkPostAccess(talkPostRepository, talkBlockRepository, memberService, routineShareService);
  }

  private void stubVisiblePost(String postId) {
    when(talkPostRepository.findById(postId)).thenReturn(Optional.of(post(postId, "author-1")));
  }

  private static TalkPost post(String id, String authorMemberId) {
    TalkPost post = new TalkPost();
    post.setId(id);
    post.setAuthorMemberId(authorMemberId);
    return post;
  }

  private static TalkComment comment(String id, String postId, String authorMemberId, LocalDateTime createdAt) {
    TalkComment comment = new TalkComment();
    comment.setId(id);
    comment.setPostId(postId);
    comment.setAuthorMemberId(authorMemberId);
    comment.setBody("내용 " + id);
    ReflectionTestUtils.setField(comment, "createdAt", createdAt);
    return comment;
  }
}
