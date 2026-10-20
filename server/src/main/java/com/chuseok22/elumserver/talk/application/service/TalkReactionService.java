package com.chuseok22.elumserver.talk.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.member.core.NicknamePolicy;
import com.chuseok22.elumserver.notification.core.event.TalkPostCommentedEvent;
import com.chuseok22.elumserver.talk.application.dto.request.TalkCommentRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkCommentPageResponse;
import com.chuseok22.elumserver.talk.application.dto.response.TalkCommentResponse;
import com.chuseok22.elumserver.talk.core.TalkCommentStatus;
import com.chuseok22.elumserver.talk.core.TalkCursor;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.core.TalkTextRules;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkBlock;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkComment;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkHelpful;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkBlockRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkCommentRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkHelpfulRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 이야기 반응: 도움이 됐어요 누르기·취소, 댓글 목록·쓰기·지우기
 * 보이는 글에만 가능, 차단한 보호자·정지 회원 댓글 제외, 댓글 원문은 로그에 남기지 않음
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TalkReactionService {

  // cursor 없음: 어떤 댓글보다 이른 시각 (cursor 조건을 항상 참으로 만듦)
  private static final LocalDateTime NO_CURSOR_CREATED_AT = LocalDateTime.of(1970, 1, 1, 0, 0);
  // 한 쪽을 채우려고 차단·정지 댓글을 건너뛰며 다시 읽는 최대 횟수
  private static final int MAX_COMMENT_SCAN_ROUNDS = 5;

  private final TalkPostRepository talkPostRepository;
  private final TalkHelpfulRepository talkHelpfulRepository;
  private final TalkCommentRepository talkCommentRepository;
  private final TalkBlockRepository talkBlockRepository;
  private final MemberService memberService;
  private final NicknamePolicy nicknamePolicy;
  private final ApplicationEventPublisher eventPublisher;

  /**
   * 도움이 됐어요 누르기: 보이는 글 확인 > 이미 눌렀으면 그대로 끝 > 기록 저장 > 수 +1
   * 트랜잭션 밖에서 저장해야 동시에 눌려 유니크가 겹쳐도 잡고 넘어갈 수 있음 (그 경우 수는 올리지 않음)
   */
  public void markHelpful(Caller caller, String postId) {
    requireVisiblePost(postId);
    if (talkHelpfulRepository.existsByPostIdAndMemberId(postId, caller.memberId())) {
      return;
    }
    TalkHelpful helpful = new TalkHelpful();
    helpful.setPostId(postId);
    helpful.setMemberId(caller.memberId());
    try {
      talkHelpfulRepository.saveAndFlush(helpful);
    } catch (DataIntegrityViolationException e) {
      log.info("[talk helpful] ignored : already marked");
      return;
    }
    talkPostRepository.increaseHelpfulCount(postId);
  }

  /**
   * 도움이 됐어요 취소: 보이는 글 확인 > 기록 삭제 > 지운 게 있을 때만 수 -1
   */
  @Transactional
  public void unmarkHelpful(Caller caller, String postId) {
    requireVisiblePost(postId);
    if (talkHelpfulRepository.deleteByPostIdAndMemberId(postId, caller.memberId()) > 0) {
      talkPostRepository.decreaseHelpfulCount(postId);
    }
  }

  /**
   * 댓글 한 쪽: 보이는 글 확인 > 오래된 순 읽기 > 차단·정지 댓글 거르기 > size 만큼 자르고 nextCursor
   * cursor 형식이 틀리면 첫 쪽, size 는 1~50 (기본 20)
   */
  @Transactional(readOnly = true)
  public TalkCommentPageResponse comments(Caller caller, String postId, String cursor, Integer size) {
    requireVisiblePost(postId);
    int pageSize = size == null ? TalkFeedQueryService.DEFAULT_PAGE_SIZE
      : Math.clamp(size, 1, TalkFeedQueryService.MAX_PAGE_SIZE);
    int fetchSize = pageSize + 1;
    Set<String> blockedAuthorIds = talkBlockRepository.findByBlockerMemberId(caller.memberId()).stream()
      .map(TalkBlock::getBlockedMemberId)
      .collect(Collectors.toSet());

    // 읽기 (한 건 더, 거른 만큼 부족하면 이어서 읽기)
    TalkCursor position = TalkCursor.decode(cursor).orElse(null);
    List<TalkComment> collected = new ArrayList<>();
    boolean isExhausted = false;
    for (int round = 0; round < MAX_COMMENT_SCAN_ROUNDS && collected.size() < fetchSize; round++) {
      List<TalkComment> batch = talkCommentRepository.findCommentPage(postId, TalkCommentStatus.VISIBLE,
        position == null ? NO_CURSOR_CREATED_AT : position.createdAt(),
        position == null ? "" : position.id(), PageRequest.of(0, fetchSize));
      if (batch.isEmpty()) {
        isExhausted = true;
        break;
      }
      for (TalkComment comment : readableComments(caller, batch, blockedAuthorIds)) {
        if (collected.size() < fetchSize) {
          collected.add(comment);
        }
      }
      TalkComment lastScanned = batch.get(batch.size() - 1);
      position = new TalkCursor(lastScanned.getCreatedAt(), lastScanned.getId());
      if (batch.size() < fetchSize) {
        isExhausted = true;
        break;
      }
    }

    // 자르기 > nextCursor (더 있을 때만, 거르다 끝난 경우는 읽은 마지막 위치에서 이어감)
    List<TalkComment> page = collected.size() > pageSize ? collected.subList(0, pageSize) : collected;
    String nextCursor = null;
    if (collected.size() > pageSize) {
      TalkComment last = page.get(page.size() - 1);
      nextCursor = TalkCursor.encode(last.getCreatedAt(), last.getId());
    } else if (!isExhausted && position != null) {
      nextCursor = TalkCursor.encode(position.createdAt(), position.id());
    }
    return new TalkCommentPageResponse(toResponses(caller, page), nextCursor);
  }

  /**
   * 댓글 쓰기: 이용 규칙 동의 > 정리(빈 값, 300자) > 금칙어 > 보이는 글 확인 > 저장 > 댓글 수 +1 > 글쓴이 알림 이벤트
   * 이룸이 호칭은 가리지 않음
   */
  @Transactional
  public TalkCommentResponse addComment(Caller caller, String postId, TalkCommentRequest request) {
    // 요청 검증 (규칙 동의, 빈 값·길이, 금칙어)
    if (!memberService.hasAgreedTalkRules(caller.memberId())) {
      throw new CustomException(ErrorCode.TALK_RULES_NOT_AGREED);
    }
    String body = TalkTextRules.normalizeComment(request == null ? null : request.body());
    if (nicknamePolicy.containsBlockedWord(body)) {
      log.warn("[talk comment] rejected 400 : blocked word in text");
      throw new CustomException(ErrorCode.TALK_TEXT_NOT_ALLOWED);
    }
    TalkPost post = requireVisiblePost(postId);

    // 저장 > 댓글 수
    TalkComment comment = new TalkComment();
    comment.setPostId(postId);
    comment.setAuthorMemberId(caller.memberId());
    comment.setBody(body);
    TalkComment saved = talkCommentRepository.save(comment);
    talkPostRepository.increaseCommentCount(postId);
    // 알림 이벤트 (커밋 뒤 리스너가 처리, 글쓴이 본인 댓글은 리스너가 거름)
    eventPublisher.publishEvent(
      new TalkPostCommentedEvent(postId, post.getAuthorMemberId(), caller.memberId(), post.getTitle()));
    log.info("[talk comment] created : postId={}", postId);
    return toResponses(caller, List.of(saved)).get(0);
  }

  /**
   * 댓글 지우기: 보이는 내 댓글 확인 > 조건부 DELETED > 바뀐 경우만 댓글 수 -1
   * 없거나 이미 지운 댓글은 TALK_COMMENT_NOT_FOUND, 남의 댓글은 TALK_NOT_AUTHOR
   */
  @Transactional
  public void deleteComment(Caller caller, String commentId) {
    TalkComment comment = talkCommentRepository.findById(commentId)
      .filter(found -> found.getStatus() == TalkCommentStatus.VISIBLE)
      .orElseThrow(() -> new CustomException(ErrorCode.TALK_COMMENT_NOT_FOUND));
    if (!comment.getAuthorMemberId().equals(caller.memberId())) {
      log.warn("[talk comment] rejected 403 : not the author");
      throw new CustomException(ErrorCode.TALK_NOT_AUTHOR);
    }
    // 내가 바꾼 경우에만 댓글 수 감소 (동시에 두 번 지워도 한 번만)
    int changedCount = talkCommentRepository.updateStatusIfVisible(
      commentId, TalkCommentStatus.DELETED, TalkCommentStatus.VISIBLE);
    if (changedCount > 0) {
      talkPostRepository.decreaseCommentCount(comment.getPostId());
      log.info("[talk comment] deleted : postId={}", comment.getPostId());
    }
  }

  // 보이지 않는 글은 없는 글로 취급
  private TalkPost requireVisiblePost(String postId) {
    return talkPostRepository.findById(postId)
      .filter(found -> found.getStatus() == TalkPostStatus.VISIBLE)
      .orElseThrow(() -> new CustomException(ErrorCode.TALK_POST_NOT_FOUND));
  }

  // 차단한 보호자·정지 회원의 댓글 제외 (내 댓글은 항상 보임)
  private List<TalkComment> readableComments(Caller caller, List<TalkComment> comments, Set<String> blockedAuthorIds) {
    Set<String> authorIds = comments.stream().map(TalkComment::getAuthorMemberId).collect(Collectors.toSet());
    Set<String> suspendedAuthorIds = new HashSet<>(memberService.suspendedAmong(authorIds));
    return comments.stream()
      .filter(comment -> comment.getAuthorMemberId().equals(caller.memberId())
        || (!blockedAuthorIds.contains(comment.getAuthorMemberId())
        && !suspendedAuthorIds.contains(comment.getAuthorMemberId())))
      .toList();
  }

  // 댓글 > 응답 (닉네임은 한 번에 읽음)
  private List<TalkCommentResponse> toResponses(Caller caller, List<TalkComment> comments) {
    if (comments.isEmpty()) {
      return List.of();
    }
    Set<String> authorIds = comments.stream().map(TalkComment::getAuthorMemberId).collect(Collectors.toSet());
    Map<String, String> nicknameByMemberId = memberService.nicknamesOf(authorIds);
    return comments.stream()
      .map(comment -> new TalkCommentResponse(comment.getId(), nicknameByMemberId.get(comment.getAuthorMemberId()),
        comment.getAuthorMemberId().equals(caller.memberId()), comment.getBody(), comment.getCreatedAt()))
      .toList();
  }
}
