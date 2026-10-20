package com.chuseok22.elumserver.talk.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.talk.application.dto.request.TalkBlockRequest;
import com.chuseok22.elumserver.talk.application.dto.request.TalkReportRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkBlockResponse;
import com.chuseok22.elumserver.talk.core.TalkCommentStatus;
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
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 이야기 신고·차단: 신고 저장과 메일 이벤트, 보호자 차단·해제·목록
 * 신고만으로 글·댓글을 숨기지 않음 (숨김은 관리자 처리)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TalkModerationService {

  private final TalkReportRepository talkReportRepository;
  private final TalkBlockRepository talkBlockRepository;
  private final TalkPostRepository talkPostRepository;
  private final TalkCommentRepository talkCommentRepository;
  private final MemberService memberService;
  private final ApplicationEventPublisher eventPublisher;

  /**
   * 신고: 요청 검증 > 대상(보이는 글·댓글) 확인 > 중복 확인 > 저장 > 메일 이벤트
   * 동시에 같은 신고가 겹치면 유니크가 막아 TALK_REPORT_DUPLICATED (이벤트는 커밋 뒤 한 번만)
   */
  @Transactional
  public void report(Caller caller, TalkReportRequest request) {
    // 요청 검증 (대상 종류, 대상 id, 사유)
    TalkReportTargetType targetType = parseOrThrow(TalkReportTargetType.class, request == null ? null : request.targetType());
    TalkReportReason reason = parseOrThrow(TalkReportReason.class, request.reason());
    if (request.targetId() == null || request.targetId().isBlank()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }

    // 대상 확인 > 중복 확인
    String postId = targetType == TalkReportTargetType.POST
      ? requireVisiblePost(request.targetId()).getId()
      : requireVisibleComment(request.targetId()).getPostId();
    if (talkReportRepository.existsByTargetTypeAndTargetIdAndReporterMemberId(
      targetType, request.targetId(), caller.memberId())) {
      throw new CustomException(ErrorCode.TALK_REPORT_DUPLICATED);
    }

    // 저장 > 메일 이벤트
    TalkReport report = new TalkReport();
    report.setTargetType(targetType);
    report.setTargetId(request.targetId());
    report.setPostId(postId);
    report.setReporterMemberId(caller.memberId());
    report.setReason(reason);
    TalkReport saved;
    try {
      saved = talkReportRepository.saveAndFlush(report);
    } catch (DataIntegrityViolationException e) {
      throw new CustomException(ErrorCode.TALK_REPORT_DUPLICATED);
    }
    eventPublisher.publishEvent(new TalkReportedEvent(saved.getId()));
    log.info("[talk report] created : targetType={}, reason={}", targetType, reason);
  }

  /**
   * 차단: 글 또는 댓글 중 하나로 글쓴이 확인 > 자기 자신 거절 > 이미 차단했으면 그대로 끝 > 저장
   * 트랜잭션 밖에서 저장해야 동시에 겹쳐 유니크에 걸려도 잡고 넘어갈 수 있음
   */
  public void block(Caller caller, TalkBlockRequest request) {
    String blockedMemberId = findTargetAuthorMemberId(request);
    if (blockedMemberId.equals(caller.memberId())) {
      throw new CustomException(ErrorCode.TALK_CANNOT_BLOCK_SELF);
    }
    if (talkBlockRepository.existsByBlockerMemberIdAndBlockedMemberId(caller.memberId(), blockedMemberId)) {
      return;
    }
    TalkBlock block = new TalkBlock();
    block.setBlockerMemberId(caller.memberId());
    block.setBlockedMemberId(blockedMemberId);
    try {
      talkBlockRepository.saveAndFlush(block);
    } catch (DataIntegrityViolationException e) {
      log.info("[talk block] ignored : already blocked");
      return;
    }
    log.info("[talk block] created");
  }

  /**
   * 차단 해제: 내 차단만 가능, 없거나 남의 차단 id 는 INVALID_INPUT_VALUE
   */
  public void unblock(Caller caller, String blockId) {
    TalkBlock block = talkBlockRepository.findById(blockId)
      .filter(found -> found.getBlockerMemberId().equals(caller.memberId()))
      .orElseThrow(() -> new CustomException(ErrorCode.INVALID_INPUT_VALUE));
    talkBlockRepository.delete(block);
    log.info("[talk block] removed");
  }

  /**
   * 내 차단 목록: 최근 차단 먼저, 닉네임은 한 번에 읽음
   */
  @Transactional(readOnly = true)
  public List<TalkBlockResponse> blocks(Caller caller) {
    List<TalkBlock> blocks = talkBlockRepository.findByBlockerMemberIdOrderByCreatedAtDesc(caller.memberId());
    Set<String> blockedMemberIds = blocks.stream().map(TalkBlock::getBlockedMemberId).collect(Collectors.toSet());
    Map<String, String> nicknameByMemberId = memberService.nicknamesOf(blockedMemberIds);
    return blocks.stream()
      .map(block -> new TalkBlockResponse(
        block.getId(), nicknameByMemberId.get(block.getBlockedMemberId()), block.getCreatedAt()))
      .toList();
  }

  // 글·댓글 중 정확히 하나 > 글쓴이 (없거나 지운 댓글은 없는 것으로 취급)
  private String findTargetAuthorMemberId(TalkBlockRequest request) {
    boolean hasPostId = request != null && request.postId() != null && !request.postId().isBlank();
    boolean hasCommentId = request != null && request.commentId() != null && !request.commentId().isBlank();
    if (hasPostId == hasCommentId) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    if (hasPostId) {
      return talkPostRepository.findById(request.postId())
        .orElseThrow(() -> new CustomException(ErrorCode.TALK_POST_NOT_FOUND))
        .getAuthorMemberId();
    }
    return talkCommentRepository.findById(request.commentId())
      .orElseThrow(() -> new CustomException(ErrorCode.TALK_COMMENT_NOT_FOUND))
      .getAuthorMemberId();
  }

  private TalkPost requireVisiblePost(String postId) {
    return talkPostRepository.findById(postId)
      .filter(found -> found.getStatus() == TalkPostStatus.VISIBLE)
      .orElseThrow(() -> new CustomException(ErrorCode.TALK_POST_NOT_FOUND));
  }

  private TalkComment requireVisibleComment(String commentId) {
    return talkCommentRepository.findById(commentId)
      .filter(found -> found.getStatus() == TalkCommentStatus.VISIBLE)
      .orElseThrow(() -> new CustomException(ErrorCode.TALK_COMMENT_NOT_FOUND));
  }

  // 문자열 > enum (없거나 모르는 값은 INVALID_INPUT_VALUE)
  private <E extends Enum<E>> E parseOrThrow(Class<E> enumType, String name) {
    if (name == null) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    try {
      return Enum.valueOf(enumType, name);
    } catch (IllegalArgumentException e) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
  }
}
