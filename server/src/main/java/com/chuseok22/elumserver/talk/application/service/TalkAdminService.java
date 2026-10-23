package com.chuseok22.elumserver.talk.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminChange;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminPostDetail;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminPostDetail.CommentRow;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminPostRow;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminReportRow;
import com.chuseok22.elumserver.talk.core.TalkCommentStatus;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
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
import java.util.HashMap;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 이야기 관리자 기능: 글 목록·상세, 글·댓글 가리기와 되돌리기, 신고 목록과 처리, 카드 그림
 * 작성자가 지운 글·댓글은 되돌리지 않음, 가린 글의 그림·내용도 관리자는 봄
 */
@Slf4j
@Service
public class TalkAdminService {

  /// 글 목록 정렬 키: 미처리 신고 수 (정렬 열 키와 같음, 이 키가 있으면 신고 정렬 쿼리를 씀)
  public static final String SORT_UNRESOLVED_REPORT_COUNT = "unresolvedReportCount";

  private final TalkPostRepository talkPostRepository;
  private final TalkPostStepRepository talkPostStepRepository;
  private final TalkCommentRepository talkCommentRepository;
  private final TalkReportRepository talkReportRepository;
  private final TalkImageStorage talkImageStorage;
  private final MemberService memberService;
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 이 앱에는 Clock 빈이 없다.
  @Autowired
  public TalkAdminService(
    TalkPostRepository talkPostRepository, TalkPostStepRepository talkPostStepRepository,
    TalkCommentRepository talkCommentRepository, TalkReportRepository talkReportRepository,
    TalkImageStorage talkImageStorage, MemberService memberService
  ) {
    this(talkPostRepository, talkPostStepRepository, talkCommentRepository, talkReportRepository, talkImageStorage,
      memberService, Clock.systemDefaultZone());
  }

  // 테스트가 시계를 고정할 수 있게 둔다
  TalkAdminService(
    TalkPostRepository talkPostRepository, TalkPostStepRepository talkPostStepRepository,
    TalkCommentRepository talkCommentRepository, TalkReportRepository talkReportRepository,
    TalkImageStorage talkImageStorage, MemberService memberService, Clock clock
  ) {
    this.talkPostRepository = talkPostRepository;
    this.talkPostStepRepository = talkPostStepRepository;
    this.talkCommentRepository = talkCommentRepository;
    this.talkReportRepository = talkReportRepository;
    this.talkImageStorage = talkImageStorage;
    this.memberService = memberService;
    this.clock = clock;
  }

  /**
   * 글 목록: 상태 필터(null 이면 전체), 제목 검색(이스케이프된 LIKE 패턴, null 이면 전체), 정렬·페이지는 pageable
   * 미처리 신고 수 정렬이면 신고 정렬 쿼리 > 글쓴이 닉네임·글별 미처리 신고 수 붙이기
   */
  @Transactional(readOnly = true)
  public Page<TalkAdminPostRow> searchPosts(String likePattern, TalkPostStatus statusFilter, Pageable pageable) {
    List<TalkPostStatus> statuses = statusFilter == null ? List.of(TalkPostStatus.values()) : List.of(statusFilter);
    boolean hasKeyword = likePattern != null;
    // 검색어가 없을 때도 파라미터 타입이 흔들리지 않게 빈 문자열을 넘긴다 (hasKeyword 가 false 면 쓰이지 않음)
    String pattern = hasKeyword ? likePattern : "";
    Sort.Order reportOrder = pageable.getSort().getOrderFor(SORT_UNRESOLVED_REPORT_COUNT);
    Page<TalkPost> posts;
    if (reportOrder == null) {
      posts = talkPostRepository.searchForAdmin(hasKeyword, pattern, statuses, pageable);
    } else {
      // 신고 수 정렬은 쿼리가 정하므로 정렬 없는 Pageable 로 넘김
      Pageable unsorted = PageRequest.of(pageable.getPageNumber(), pageable.getPageSize());
      posts = reportOrder.isAscending()
        ? talkPostRepository.searchForAdminByUnresolvedReportsAscending(hasKeyword, pattern, statuses, unsorted)
        : talkPostRepository.searchForAdminByUnresolvedReportsDescending(hasKeyword, pattern, statuses, unsorted);
    }
    if (posts.isEmpty()) {
      return posts.map(post -> new TalkAdminPostRow(post, null, 0));
    }

    Map<String, Long> unresolvedCountByPostId = unresolvedReportCounts(posts.getContent());
    Map<String, String> nicknameByMemberId = memberService.nicknamesOf(
      posts.getContent().stream().map(TalkPost::getAuthorMemberId).collect(Collectors.toSet()));
    return posts.map(post -> new TalkAdminPostRow(post, nicknameByMemberId.get(post.getAuthorMemberId()),
      unresolvedCountByPostId.getOrDefault(post.getId(), 0L)));
  }

  /**
   * 글 상세: 글(상태 무관) > 카드 > 모든 상태 댓글 > 신고 (닉네임은 글쓴이·댓글쓴이·신고자를 한 번에 읽음)
   */
  @Transactional(readOnly = true)
  public TalkAdminPostDetail getPostDetail(String postId) {
    TalkPost post = requirePost(postId);
    List<TalkPostStep> steps = talkPostStepRepository.findByPostIdOrderByStepOrderAsc(postId);
    List<TalkComment> comments = talkCommentRepository.findByPostIdOrderByCreatedAtAscIdAsc(postId);
    List<TalkReport> reports = talkReportRepository.findByPostIdOrderByCreatedAtDescIdAsc(postId);

    Set<String> memberIds = new HashSet<>();
    memberIds.add(post.getAuthorMemberId());
    comments.forEach(comment -> memberIds.add(comment.getAuthorMemberId()));
    reports.forEach(report -> memberIds.add(report.getReporterMemberId()));
    Map<String, String> nicknameByMemberId = memberService.nicknamesOf(memberIds);

    // 댓글 신고의 대상 내용은 이 글의 댓글 안에 있음
    Map<String, String> commentBodyById = comments.stream()
      .collect(Collectors.toMap(TalkComment::getId, TalkComment::getBody, (first, second) -> first));
    List<CommentRow> commentRows = comments.stream()
      .map(comment -> new CommentRow(comment, nicknameByMemberId.get(comment.getAuthorMemberId())))
      .toList();
    return new TalkAdminPostDetail(post, nicknameByMemberId.get(post.getAuthorMemberId()), steps, commentRows,
      toReportRows(reports, nicknameByMemberId, Map.of(post.getId(), post.getTitle()), commentBodyById));
  }

  /**
   * 글 가리기: 글 확인 > 보이는 글만 가림 상태로 > 가린 경우 그 글의 미처리 신고도 처리 (이미 가렸거나 지운 글은 UNCHANGED)
   */
  public TalkAdminChange hidePost(String postId) {
    requirePost(postId);
    int changedCount = talkPostRepository.updateStatusIfCurrent(
      postId, TalkPostStatus.HIDDEN_BY_ADMIN, TalkPostStatus.VISIBLE);
    if (changedCount == 0) {
      return new TalkAdminChange(postId, TalkAdminChange.Result.UNCHANGED);
    }
    talkReportRepository.markResolvedByPostIds(List.of(postId), LocalDateTime.now(clock));
    return new TalkAdminChange(postId, TalkAdminChange.Result.CHANGED);
  }

  /**
   * 글 여러 개 가리기: 중복 id 제거 > 보이는 글만 가림 상태로 > 가린 글들의 미처리 신고도 한 번에 처리
   * (가린 건수 반환, 이미 가렸거나 지운 글·없는 글은 제외)
   */
  public int hidePosts(Collection<String> postIds) {
    List<String> hiddenPostIds = new ArrayList<>();
    for (String postId : new LinkedHashSet<>(postIds)) {
      int changedCount = talkPostRepository.updateStatusIfCurrent(
        postId, TalkPostStatus.HIDDEN_BY_ADMIN, TalkPostStatus.VISIBLE);
      if (changedCount > 0) {
        hiddenPostIds.add(postId);
      }
    }
    if (!hiddenPostIds.isEmpty()) {
      talkReportRepository.markResolvedByPostIds(hiddenPostIds, LocalDateTime.now(clock));
    }
    return hiddenPostIds.size();
  }

  /**
   * 글 되돌리기: 글 확인 > 가린 글만 보이는 글로 (지운 글은 UNCHANGED)
   * 같은 일과로 올린 보이는 글이 따로 있으면 유니크에 걸려 SOURCE_ALREADY_VISIBLE (트랜잭션 밖이라 이 예외로 롤백 표시가 남지 않음)
   */
  public TalkAdminChange restorePost(String postId) {
    requirePost(postId);
    try {
      int changedCount = talkPostRepository.updateStatusIfCurrent(
        postId, TalkPostStatus.VISIBLE, TalkPostStatus.HIDDEN_BY_ADMIN);
      return new TalkAdminChange(postId, changedCount > 0 ? TalkAdminChange.Result.CHANGED
        : TalkAdminChange.Result.UNCHANGED);
    } catch (DataIntegrityViolationException e) {
      log.warn("[talk admin] restore rejected : visible post of the same source exists, postId={}", postId);
      return new TalkAdminChange(postId, TalkAdminChange.Result.SOURCE_ALREADY_VISIBLE);
    }
  }

  /**
   * 댓글 가리기: 댓글 확인 > 보이는 댓글만 가림 상태로 > 바꾼 경우에만 글의 댓글 수 감소
   */
  @Transactional
  public TalkAdminChange hideComment(String commentId) {
    TalkComment comment = requireComment(commentId);
    int changedCount = talkCommentRepository.updateStatusIfCurrent(
      commentId, TalkCommentStatus.HIDDEN_BY_ADMIN, TalkCommentStatus.VISIBLE);
    if (changedCount == 0) {
      return new TalkAdminChange(comment.getPostId(), TalkAdminChange.Result.UNCHANGED);
    }
    talkPostRepository.decreaseCommentCount(comment.getPostId());
    talkReportRepository.markResolvedByTarget(TalkReportTargetType.COMMENT, commentId, LocalDateTime.now(clock));
    return new TalkAdminChange(comment.getPostId(), TalkAdminChange.Result.CHANGED);
  }

  /**
   * 댓글 되돌리기: 댓글 확인 > 가린 댓글만 보이는 댓글로 > 바꾼 경우에만 글의 댓글 수 증가 (지운 댓글은 UNCHANGED)
   */
  @Transactional
  public TalkAdminChange restoreComment(String commentId) {
    TalkComment comment = requireComment(commentId);
    int changedCount = talkCommentRepository.updateStatusIfCurrent(
      commentId, TalkCommentStatus.VISIBLE, TalkCommentStatus.HIDDEN_BY_ADMIN);
    if (changedCount == 0) {
      return new TalkAdminChange(comment.getPostId(), TalkAdminChange.Result.UNCHANGED);
    }
    talkPostRepository.increaseCommentCount(comment.getPostId());
    return new TalkAdminChange(comment.getPostId(), TalkAdminChange.Result.CHANGED);
  }

  /**
   * 신고 목록: 처리 상태 필터(true 처리 완료, false 미처리, null 전체), 정렬·페이지는 pageable
   * 신고자 닉네임·대상 글 제목·댓글 신고의 댓글 내용 붙이기
   */
  @Transactional(readOnly = true)
  public Page<TalkAdminReportRow> searchReports(Boolean resolvedFilter, Pageable pageable) {
    Page<TalkReport> reports;
    if (resolvedFilter == null) {
      reports = talkReportRepository.findAll(pageable);
    } else if (resolvedFilter) {
      reports = talkReportRepository.findByResolvedAtIsNotNull(pageable);
    } else {
      reports = talkReportRepository.findByResolvedAtIsNull(pageable);
    }
    if (reports.isEmpty()) {
      return reports.map(report -> new TalkAdminReportRow(report, null, null, null));
    }

    Set<String> postIds = reports.getContent().stream().map(TalkReport::getPostId).collect(Collectors.toSet());
    Set<String> commentIds = reports.getContent().stream()
      .filter(report -> report.getTargetType() == TalkReportTargetType.COMMENT)
      .map(TalkReport::getTargetId).collect(Collectors.toSet());
    Map<String, String> postTitleById = talkPostRepository.findAllById(postIds).stream()
      .collect(Collectors.toMap(TalkPost::getId, TalkPost::getTitle, (first, second) -> first));
    Map<String, String> commentBodyById = commentIds.isEmpty() ? Map.of()
      : talkCommentRepository.findAllById(commentIds).stream()
      .collect(Collectors.toMap(TalkComment::getId, TalkComment::getBody, (first, second) -> first));
    Map<String, String> nicknameByMemberId = memberService.nicknamesOf(
      reports.getContent().stream().map(TalkReport::getReporterMemberId).collect(Collectors.toSet()));

    List<TalkAdminReportRow> rows = toReportRows(reports.getContent(), nicknameByMemberId, postTitleById, commentBodyById);
    Map<String, TalkAdminReportRow> rowByReportId = rows.stream()
      .collect(Collectors.toMap(row -> row.report().getId(), Function.identity()));
    return reports.map(report -> rowByReportId.get(report.getId()));
  }

  /**
   * 신고 처리: 신고 확인 > 미처리일 때만 처리 시각 기록 (이미 처리했으면 UNCHANGED, 없는 신고는 INVALID_INPUT_VALUE)
   * 돌려주는 postId 는 신고가 속한 글 (화면이 글 상세로 돌아갈 때 씀)
   */
  @Transactional
  public TalkAdminChange resolveReport(String reportId) {
    TalkReport report = talkReportRepository.findById(reportId)
      .orElseThrow(() -> new CustomException(ErrorCode.INVALID_INPUT_VALUE));
    int changedCount = talkReportRepository.markResolvedIfUnresolved(reportId, LocalDateTime.now(clock));
    return new TalkAdminChange(report.getPostId(), changedCount > 0 ? TalkAdminChange.Result.CHANGED
      : TalkAdminChange.Result.UNCHANGED);
  }

  /// 아직 처리하지 않은 신고 수 (사이드 메뉴 배지)
  @Transactional(readOnly = true)
  public long countUnresolvedReports() {
    return talkReportRepository.countByResolvedAtIsNull();
  }

  /**
   * 카드 그림: 카드의 그림 열쇠 > 파일 읽기 (글 상태는 보지 않음: 가린·지운 글도 관리자는 봄, 없으면 TALK_IMAGE_NOT_FOUND)
   */
  @Transactional(readOnly = true)
  public ImageContent stepImage(String postId, int stepOrder) {
    String imageKey = talkPostStepRepository.findByPostIdAndStepOrder(postId, stepOrder)
      .map(TalkPostStep::getImageKey)
      .orElseThrow(() -> new CustomException(ErrorCode.TALK_IMAGE_NOT_FOUND));
    return talkImageStorage.read(imageKey);
  }

  private TalkPost requirePost(String postId) {
    return talkPostRepository.findById(postId)
      .orElseThrow(() -> new CustomException(ErrorCode.TALK_POST_NOT_FOUND));
  }

  private TalkComment requireComment(String commentId) {
    return talkCommentRepository.findById(commentId)
      .orElseThrow(() -> new CustomException(ErrorCode.TALK_COMMENT_NOT_FOUND));
  }

  // 글별 미처리 신고 수 (신고 없는 글은 빠짐)
  private Map<String, Long> unresolvedReportCounts(List<TalkPost> posts) {
    Map<String, Long> countByPostId = new HashMap<>();
    for (Object[] row : talkReportRepository.countUnresolvedByPostIds(posts.stream().map(TalkPost::getId).toList())) {
      countByPostId.put((String) row[0], ((Number) row[1]).longValue());
    }
    return countByPostId;
  }

  private static List<TalkAdminReportRow> toReportRows(
    List<TalkReport> reports, Map<String, String> nicknameByMemberId, Map<String, String> postTitleById,
    Map<String, String> commentBodyById
  ) {
    return reports.stream()
      .map(report -> new TalkAdminReportRow(report, nicknameByMemberId.get(report.getReporterMemberId()),
        postTitleById.get(report.getPostId()),
        report.getTargetType() == TalkReportTargetType.COMMENT ? commentBodyById.get(report.getTargetId()) : null))
      .toList();
  }
}
