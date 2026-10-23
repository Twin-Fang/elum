package com.chuseok22.elumserver.talk.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminChange;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminPostDetail;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminPostRow;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminReportRow;
import com.chuseok22.elumserver.talk.core.TalkCommentStatus;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.core.TalkReportReason;
import com.chuseok22.elumserver.talk.core.TalkReportTargetType;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkComment;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPostStep;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkReport;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkCommentRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostStepRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkReportRepository;
import com.chuseok22.elumserver.talk.infrastructure.storage.TalkImageStorage;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
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
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/// 관리자 가리기·되돌리기(지운 것은 그대로, 댓글 수 증감), 신고 처리, 글 목록·상세, 숨긴 글 그림을 막는다.
@ExtendWith(MockitoExtension.class)
class TalkAdminServiceTest {

  private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");
  private static final LocalDateTime NOW = LocalDateTime.of(2026, 10, 20, 12, 0);

  @Mock
  private TalkPostRepository talkPostRepository;
  @Mock
  private TalkPostStepRepository talkPostStepRepository;
  @Mock
  private TalkCommentRepository talkCommentRepository;
  @Mock
  private TalkReportRepository talkReportRepository;
  @Mock
  private TalkImageStorage talkImageStorage;
  @Mock
  private MemberService memberService;

  private TalkAdminService talkAdminService;

  @BeforeEach
  void setUp() {
    Clock clock = Clock.fixed(NOW.atZone(ZONE).toInstant(), ZONE);
    talkAdminService = new TalkAdminService(talkPostRepository, talkPostStepRepository, talkCommentRepository,
      talkReportRepository, talkImageStorage, memberService, clock);
  }

  private static TalkPost post(String id, TalkPostStatus status) {
    TalkPost post = new TalkPost();
    post.setId(id);
    post.setAuthorMemberId("author-" + id);
    post.setTitle("제목 " + id);
    post.setStatus(status);
    return post;
  }

  private static TalkComment comment(String id, String postId, TalkCommentStatus status) {
    TalkComment comment = new TalkComment();
    comment.setId(id);
    comment.setPostId(postId);
    comment.setAuthorMemberId("commenter-" + id);
    comment.setBody("댓글 " + id);
    comment.setStatus(status);
    return comment;
  }

  private static TalkReport report(String id, TalkReportTargetType type, String targetId, String postId) {
    TalkReport report = new TalkReport();
    report.setId(id);
    report.setTargetType(type);
    report.setTargetId(targetId);
    report.setPostId(postId);
    report.setReporterMemberId("reporter-" + id);
    report.setReason(TalkReportReason.OFFENSIVE);
    return report;
  }

  @Test
  @DisplayName("hide_setsHiddenByAdmin: 보이는 글만 가림 상태로 바꾼다")
  void hidePost_setsHiddenByAdmin() {
    when(talkPostRepository.findById("p1")).thenReturn(Optional.of(post("p1", TalkPostStatus.VISIBLE)));
    when(talkPostRepository.updateStatusIfCurrent("p1", TalkPostStatus.HIDDEN_BY_ADMIN, TalkPostStatus.VISIBLE))
      .thenReturn(1);

    TalkAdminChange change = talkAdminService.hidePost("p1");

    assertThat(change.isChanged()).isTrue();
    assertThat(change.postId()).isEqualTo("p1");
  }

  @Test
  @DisplayName("이미 가렸거나 지운 글을 가리면 바뀐 것 없음이다")
  void hidePost_alreadyNotVisible_isUnchanged() {
    when(talkPostRepository.findById("p1")).thenReturn(Optional.of(post("p1", TalkPostStatus.DELETED)));
    when(talkPostRepository.updateStatusIfCurrent("p1", TalkPostStatus.HIDDEN_BY_ADMIN, TalkPostStatus.VISIBLE))
      .thenReturn(0);

    assertThat(talkAdminService.hidePost("p1").result()).isEqualTo(TalkAdminChange.Result.UNCHANGED);
  }

  @Test
  @DisplayName("없는 글을 가리면 TALK_POST_NOT_FOUND")
  void hidePost_unknown_throws() {
    when(talkPostRepository.findById("nope")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> talkAdminService.hidePost("nope")).isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.TALK_POST_NOT_FOUND);
  }

  @Test
  @DisplayName("hidePosts: 중복 id는 한 번만 가리고, 실제로 가린 글 수만 돌려준다")
  void hidePosts_countsOnlyActuallyHidden() {
    when(talkPostRepository.updateStatusIfCurrent("p1", TalkPostStatus.HIDDEN_BY_ADMIN, TalkPostStatus.VISIBLE))
      .thenReturn(1);
    when(talkPostRepository.updateStatusIfCurrent("p2", TalkPostStatus.HIDDEN_BY_ADMIN, TalkPostStatus.VISIBLE))
      .thenReturn(0);

    assertThat(talkAdminService.hidePosts(List.of("p1", "p2", "p1"))).isEqualTo(1);
    verify(talkPostRepository, times(1))
      .updateStatusIfCurrent("p1", TalkPostStatus.HIDDEN_BY_ADMIN, TalkPostStatus.VISIBLE);
  }

  @Test
  @DisplayName("restore_setsVisible: 가린 글만 보이는 글로 되돌린다")
  void restorePost_setsVisible() {
    when(talkPostRepository.findById("p1")).thenReturn(Optional.of(post("p1", TalkPostStatus.HIDDEN_BY_ADMIN)));
    when(talkPostRepository.updateStatusIfCurrent("p1", TalkPostStatus.VISIBLE, TalkPostStatus.HIDDEN_BY_ADMIN))
      .thenReturn(1);

    assertThat(talkAdminService.restorePost("p1").isChanged()).isTrue();
  }

  @Test
  @DisplayName("작성자가 지운 글은 되돌리지 않는다 (지운 상태에서 보이는 상태로 바꾸는 갱신을 시도하지 않음)")
  void restorePost_deleted_staysDeleted() {
    when(talkPostRepository.findById("p1")).thenReturn(Optional.of(post("p1", TalkPostStatus.DELETED)));
    when(talkPostRepository.updateStatusIfCurrent("p1", TalkPostStatus.VISIBLE, TalkPostStatus.HIDDEN_BY_ADMIN))
      .thenReturn(0);

    assertThat(talkAdminService.restorePost("p1").result()).isEqualTo(TalkAdminChange.Result.UNCHANGED);
    verify(talkPostRepository, never()).updateStatusIfCurrent(any(), any(), eq(TalkPostStatus.DELETED));
  }

  @Test
  @DisplayName("같은 일과로 올린 보이는 글이 이미 있으면 되돌리지 않고 그 사실을 알린다")
  void restorePost_sourceAlreadyVisible() {
    when(talkPostRepository.findById("p1")).thenReturn(Optional.of(post("p1", TalkPostStatus.HIDDEN_BY_ADMIN)));
    when(talkPostRepository.updateStatusIfCurrent("p1", TalkPostStatus.VISIBLE, TalkPostStatus.HIDDEN_BY_ADMIN))
      .thenThrow(new DataIntegrityViolationException("uk_talk_post_visible_source"));

    assertThat(talkAdminService.restorePost("p1").result()).isEqualTo(TalkAdminChange.Result.SOURCE_ALREADY_VISIBLE);
  }

  @Test
  @DisplayName("댓글을 가리면 글의 댓글 수를 하나 줄인다")
  void hideComment_decreasesCommentCount() {
    when(talkCommentRepository.findById("c1")).thenReturn(Optional.of(comment("c1", "p1", TalkCommentStatus.VISIBLE)));
    when(talkCommentRepository.updateStatusIfCurrent("c1", TalkCommentStatus.HIDDEN_BY_ADMIN, TalkCommentStatus.VISIBLE))
      .thenReturn(1);

    TalkAdminChange change = talkAdminService.hideComment("c1");

    assertThat(change.isChanged()).isTrue();
    assertThat(change.postId()).isEqualTo("p1");
    verify(talkPostRepository).decreaseCommentCount("p1");
  }

  @Test
  @DisplayName("이미 가렸거나 지운 댓글이면 댓글 수를 건드리지 않는다 (동시에 눌러도 한 번만 줄어듦)")
  void hideComment_notChanged_keepsCommentCount() {
    when(talkCommentRepository.findById("c1")).thenReturn(Optional.of(comment("c1", "p1", TalkCommentStatus.DELETED)));
    when(talkCommentRepository.updateStatusIfCurrent("c1", TalkCommentStatus.HIDDEN_BY_ADMIN, TalkCommentStatus.VISIBLE))
      .thenReturn(0);

    assertThat(talkAdminService.hideComment("c1").isChanged()).isFalse();
    verify(talkPostRepository, never()).decreaseCommentCount(any());
  }

  @Test
  @DisplayName("가린 댓글을 되돌리면 글의 댓글 수를 하나 늘린다")
  void restoreComment_increasesCommentCount() {
    when(talkCommentRepository.findById("c1"))
      .thenReturn(Optional.of(comment("c1", "p1", TalkCommentStatus.HIDDEN_BY_ADMIN)));
    when(talkCommentRepository.updateStatusIfCurrent("c1", TalkCommentStatus.VISIBLE, TalkCommentStatus.HIDDEN_BY_ADMIN))
      .thenReturn(1);

    assertThat(talkAdminService.restoreComment("c1").isChanged()).isTrue();
    verify(talkPostRepository).increaseCommentCount("p1");
  }

  @Test
  @DisplayName("지운 댓글은 되돌리지 않고 댓글 수도 그대로다")
  void restoreComment_deleted_staysDeleted() {
    when(talkCommentRepository.findById("c1")).thenReturn(Optional.of(comment("c1", "p1", TalkCommentStatus.DELETED)));
    when(talkCommentRepository.updateStatusIfCurrent("c1", TalkCommentStatus.VISIBLE, TalkCommentStatus.HIDDEN_BY_ADMIN))
      .thenReturn(0);

    assertThat(talkAdminService.restoreComment("c1").isChanged()).isFalse();
    verify(talkPostRepository, never()).increaseCommentCount(any());
  }

  @Test
  @DisplayName("없는 댓글은 TALK_COMMENT_NOT_FOUND")
  void hideComment_unknown_throws() {
    when(talkCommentRepository.findById("nope")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> talkAdminService.hideComment("nope")).isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.TALK_COMMENT_NOT_FOUND);
  }

  @Test
  @DisplayName("신고 처리는 지금 시각을 기록하고, 없는 신고는 INVALID_INPUT_VALUE")
  void resolveReport_marksResolvedAtNow() {
    when(talkReportRepository.findById("r1")).thenReturn(Optional.of(report("r1", TalkReportTargetType.POST, "p1", "p1")));
    when(talkReportRepository.markResolvedIfUnresolved("r1", NOW)).thenReturn(1);

    TalkAdminChange change = talkAdminService.resolveReport("r1");
    assertThat(change.isChanged()).isTrue();
    assertThat(change.postId()).isEqualTo("p1");

    when(talkReportRepository.findById("nope")).thenReturn(Optional.empty());
    assertThatThrownBy(() -> talkAdminService.resolveReport("nope")).isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE);
  }

  @Test
  @DisplayName("이미 처리한 신고는 처리 시각을 다시 쓰지 않는다")
  void resolveReport_alreadyResolved_returnsFalse() {
    when(talkReportRepository.findById("r1")).thenReturn(Optional.of(report("r1", TalkReportTargetType.POST, "p1", "p1")));
    when(talkReportRepository.markResolvedIfUnresolved("r1", NOW)).thenReturn(0);

    assertThat(talkAdminService.resolveReport("r1").result()).isEqualTo(TalkAdminChange.Result.UNCHANGED);
  }

  @Test
  @DisplayName("posts_listsWithReportCount: 글 목록은 글쓴이 닉네임과 글별 미처리 신고 수를 붙인다")
  void searchPosts_attachesNicknameAndReportCount() {
    TalkPost first = post("p1", TalkPostStatus.VISIBLE);
    TalkPost second = post("p2", TalkPostStatus.HIDDEN_BY_ADMIN);
    Pageable pageable = PageRequest.of(0, 20, Sort.by(Sort.Order.desc("createdAt"), Sort.Order.asc("id")));
    when(talkPostRepository.searchForAdmin(eq(false), eq(""), eq(List.of(TalkPostStatus.values())), eq(pageable)))
      .thenReturn(new PageImpl<>(List.of(first, second), pageable, 2));
    when(talkReportRepository.countUnresolvedByPostIds(anyCollection()))
      .thenReturn(java.util.Collections.singletonList(new Object[] {"p2", 3L}));
    when(memberService.nicknamesOf(anyCollection())).thenReturn(Map.of("author-p1", "하늘"));

    Page<TalkAdminPostRow> rows = talkAdminService.searchPosts(null, null, pageable);

    assertThat(rows.getContent()).extracting(row -> row.post().getId()).containsExactly("p1", "p2");
    assertThat(rows.getContent()).extracting(TalkAdminPostRow::unresolvedReportCount).containsExactly(0L, 3L);
    assertThat(rows.getContent()).extracting(TalkAdminPostRow::authorNickname).containsExactly("하늘", null);
  }

  @Test
  @DisplayName("상태 필터와 검색어는 그대로 쓰고, 신고 수 정렬은 정렬 없는 Pageable 로 신고 정렬 쿼리를 쓴다")
  void searchPosts_reportCountSort_usesReportOrderedQuery() {
    Sort bySort = Sort.by(Sort.Order.desc(TalkAdminService.SORT_UNRESOLVED_REPORT_COUNT), Sort.Order.asc("id"));
    when(talkPostRepository.searchForAdminByUnresolvedReportsDescending(eq(true), eq("%a%"),
      eq(List.of(TalkPostStatus.VISIBLE)), any(Pageable.class))).thenReturn(new PageImpl<>(List.of()));

    talkAdminService.searchPosts("%a%", TalkPostStatus.VISIBLE, PageRequest.of(2, 20, bySort));

    ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
    verify(talkPostRepository).searchForAdminByUnresolvedReportsDescending(eq(true), eq("%a%"),
      eq(List.of(TalkPostStatus.VISIBLE)), pageable.capture());
    assertThat(pageable.getValue().getPageNumber()).isEqualTo(2);
    assertThat(pageable.getValue().getSort().isSorted()).isFalse();

    Sort ascending = Sort.by(Sort.Order.asc(TalkAdminService.SORT_UNRESOLVED_REPORT_COUNT));
    when(talkPostRepository.searchForAdminByUnresolvedReportsAscending(eq(false), eq(""),
      eq(List.of(TalkPostStatus.values())), any(Pageable.class))).thenReturn(new PageImpl<>(List.of()));
    talkAdminService.searchPosts(null, null, PageRequest.of(0, 20, ascending));
    verify(talkPostRepository).searchForAdminByUnresolvedReportsAscending(eq(false), eq(""),
      eq(List.of(TalkPostStatus.values())), any(Pageable.class));
  }

  @Test
  @DisplayName("글 상세는 가린 글도 카드·모든 상태 댓글·신고(신고자 닉네임·대상 내용)를 모아 준다")
  void getPostDetail_collectsEverything() {
    TalkPost hidden = post("p1", TalkPostStatus.HIDDEN_BY_ADMIN);
    TalkPostStep step = new TalkPostStep();
    step.setPostId("p1");
    TalkComment hiddenComment = comment("c1", "p1", TalkCommentStatus.HIDDEN_BY_ADMIN);
    when(talkPostRepository.findById("p1")).thenReturn(Optional.of(hidden));
    when(talkPostStepRepository.findByPostIdOrderByStepOrderAsc("p1")).thenReturn(List.of(step));
    when(talkCommentRepository.findByPostIdOrderByCreatedAtAscIdAsc("p1")).thenReturn(List.of(hiddenComment));
    when(talkReportRepository.findByPostIdOrderByCreatedAtDescIdAsc("p1")).thenReturn(List.of(
      report("r1", TalkReportTargetType.COMMENT, "c1", "p1"), report("r2", TalkReportTargetType.POST, "p1", "p1")));
    when(memberService.nicknamesOf(anyCollection()))
      .thenReturn(Map.of("author-p1", "하늘", "commenter-c1", "구름", "reporter-r1", "바람"));

    TalkAdminPostDetail detail = talkAdminService.getPostDetail("p1");

    assertThat(detail.post()).isSameAs(hidden);
    assertThat(detail.authorNickname()).isEqualTo("하늘");
    assertThat(detail.steps()).containsExactly(step);
    assertThat(detail.comments()).singleElement().satisfies(row -> {
      assertThat(row.comment()).isSameAs(hiddenComment);
      assertThat(row.authorNickname()).isEqualTo("구름");
    });
    assertThat(detail.reports()).extracting(TalkAdminReportRow::reporterNickname).containsExactly("바람", null);
    assertThat(detail.reports().get(0).commentBody()).isEqualTo("댓글 c1");
    assertThat(detail.reports().get(0).postTitle()).isEqualTo("제목 p1");
    assertThat(detail.reports().get(1).commentBody()).isNull();
  }

  @Test
  @DisplayName("없는 글 상세는 TALK_POST_NOT_FOUND")
  void getPostDetail_unknown_throws() {
    when(talkPostRepository.findById("nope")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> talkAdminService.getPostDetail("nope")).isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.TALK_POST_NOT_FOUND);
  }

  @Test
  @DisplayName("신고 목록: 처리 상태 필터별 조회에 글 제목·댓글 내용·신고자 닉네임을 붙인다")
  void searchReports_attachesTargets() {
    Pageable pageable = PageRequest.of(0, 20, Sort.by(Sort.Order.desc("createdAt"), Sort.Order.asc("id")));
    TalkReport commentReport = report("r1", TalkReportTargetType.COMMENT, "c1", "p1");
    when(talkReportRepository.findByResolvedAtIsNull(pageable))
      .thenReturn(new PageImpl<>(List.of(commentReport), pageable, 1));
    when(talkPostRepository.findAllById(anyCollection())).thenReturn(List.of(post("p1", TalkPostStatus.VISIBLE)));
    when(talkCommentRepository.findAllById(anyCollection()))
      .thenReturn(List.of(comment("c1", "p1", TalkCommentStatus.VISIBLE)));
    when(memberService.nicknamesOf(anyCollection())).thenReturn(Map.of("reporter-r1", "바람"));

    Page<TalkAdminReportRow> rows = talkAdminService.searchReports(Boolean.FALSE, pageable);

    assertThat(rows.getContent()).singleElement().satisfies(row -> {
      assertThat(row.reporterNickname()).isEqualTo("바람");
      assertThat(row.postTitle()).isEqualTo("제목 p1");
      assertThat(row.commentBody()).isEqualTo("댓글 c1");
    });
    verify(talkReportRepository, never()).findByResolvedAtIsNotNull(any());

    when(talkReportRepository.findByResolvedAtIsNotNull(pageable)).thenReturn(new PageImpl<>(List.of()));
    when(talkReportRepository.findAll(pageable)).thenReturn(new PageImpl<>(List.of()));
    talkAdminService.searchReports(Boolean.TRUE, pageable);
    talkAdminService.searchReports(null, pageable);
    verify(talkReportRepository).findByResolvedAtIsNotNull(pageable);
    verify(talkReportRepository).findAll(pageable);
  }

  @Test
  @DisplayName("stepImage_hiddenPost_stillServed: 가린 글의 카드 그림도 읽어 준다")
  void stepImage_hiddenPost_stillServed() {
    TalkPostStep step = new TalkPostStep();
    step.setImageKey("p1/0.png");
    ImageContent content = new ImageContent(new byte[] {1, 2}, "image/png");
    when(talkPostStepRepository.findByPostIdAndStepOrder("p1", 0)).thenReturn(Optional.of(step));
    when(talkImageStorage.read("p1/0.png")).thenReturn(content);

    assertThat(talkAdminService.stepImage("p1", 0)).isSameAs(content);
    verify(talkPostRepository, never()).findById(any());
  }

  @Test
  @DisplayName("올린 그림이 없는 카드나 없는 카드는 TALK_IMAGE_NOT_FOUND")
  void stepImage_noKey_throws() {
    TalkPostStep withoutImage = new TalkPostStep();
    when(talkPostStepRepository.findByPostIdAndStepOrder("p1", 0)).thenReturn(Optional.of(withoutImage));
    when(talkPostStepRepository.findByPostIdAndStepOrder("p1", 9)).thenReturn(Optional.empty());

    assertThatThrownBy(() -> talkAdminService.stepImage("p1", 0)).isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.TALK_IMAGE_NOT_FOUND);
    assertThatThrownBy(() -> talkAdminService.stepImage("p1", 9)).isInstanceOf(CustomException.class);
  }

  @Test
  @DisplayName("미처리 신고 수는 사이드 메뉴 배지에 쓴다")
  void countUnresolvedReports_delegates() {
    when(talkReportRepository.countByResolvedAtIsNull()).thenReturn(4L);

    assertThat(talkAdminService.countUnresolvedReports()).isEqualTo(4L);
  }
}
