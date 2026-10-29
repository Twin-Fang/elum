package com.chuseok22.elumserver.talk.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkBlock;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkBlockRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 이야기 글 접근 규칙: 보이는 글 확인, 내가 차단한 글쓴이·정지 회원 글 제외 (내 글은 항상 보임)
 * 피드·상세·그림·쓰기(도움·댓글·가져가기)가 모두 같은 규칙을 거침
 */
@Component
@RequiredArgsConstructor
public class TalkPostAccess {

  private final TalkPostRepository talkPostRepository;
  private final TalkBlockRepository talkBlockRepository;
  private final MemberService memberService;

  /**
   * 읽을 수 있는 글 한 건: 보이는 글 > 차단·정지 글쓴이 제외 (아니면 TALK_POST_NOT_FOUND)
   */
  public TalkPost requireReadablePost(Caller caller, String postId) {
    return findReadablePost(caller, postId)
      .orElseThrow(() -> new CustomException(ErrorCode.TALK_POST_NOT_FOUND));
  }

  public Optional<TalkPost> findReadablePost(Caller caller, String postId) {
    return talkPostRepository.findById(postId)
      .filter(found -> found.getStatus() == TalkPostStatus.VISIBLE)
      .filter(found -> !readablePosts(caller, List.of(found), blockedAuthorIdsOf(caller)).isEmpty());
  }

  /**
   * 앱 밖 공개 조회 한 건: 보이는 글 > 정지 글쓴이 제외 (보는 사람이 없어 차단은 보지 않음)
   */
  public Optional<TalkPost> findPubliclyVisiblePost(String postId) {
    return talkPostRepository.findById(postId)
      .filter(found -> found.getStatus() == TalkPostStatus.VISIBLE)
      .filter(found -> memberService.suspendedAmong(List.of(found.getAuthorMemberId())).isEmpty());
  }

  // 내가 차단한 글쓴이 id
  public Set<String> blockedAuthorIdsOf(Caller caller) {
    return talkBlockRepository.findByBlockerMemberId(caller.memberId()).stream()
      .map(TalkBlock::getBlockedMemberId)
      .collect(Collectors.toSet());
  }

  // 차단한 보호자·정지 회원의 글 제외 (내 글은 항상 보임)
  public List<TalkPost> readablePosts(Caller caller, List<TalkPost> posts, Set<String> blockedAuthorIds) {
    Set<String> authorIds = posts.stream().map(TalkPost::getAuthorMemberId).collect(Collectors.toSet());
    Set<String> suspendedAuthorIds = new HashSet<>(memberService.suspendedAmong(authorIds));
    return posts.stream()
      .filter(post -> post.getAuthorMemberId().equals(caller.memberId())
        || (!blockedAuthorIds.contains(post.getAuthorMemberId())
        && !suspendedAuthorIds.contains(post.getAuthorMemberId())))
      .toList();
  }
}
