package com.chuseok22.elumserver.talk.application.service;

import com.chuseok22.elumserver.talk.infrastructure.repository.TalkBlockRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkCommentRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkHelpfulRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkImportRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostStepRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkReportRepository;
import com.chuseok22.elumserver.talk.infrastructure.storage.TalkImageStorage;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * 이야기 탈퇴 정리: 글·카드·댓글·도움돼요·신고·차단·가져가기 기록 삭제, 남은 글의 집계 재계산, 글 그림 삭제
 * 일과의 talk_post_id 와 다른 보호자의 알림은 건드리지 않음 (알림은 눌렀을 때 글 없음으로 처리)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TalkCleanupService {

  private final TalkPostRepository talkPostRepository;
  private final TalkPostStepRepository talkPostStepRepository;
  private final TalkCommentRepository talkCommentRepository;
  private final TalkHelpfulRepository talkHelpfulRepository;
  private final TalkImportRepository talkImportRepository;
  private final TalkReportRepository talkReportRepository;
  private final TalkBlockRepository talkBlockRepository;
  private final TalkImageStorage talkImageStorage;

  /**
   * 회원 이야기 데이터 삭제: 집계 대상 수집 > 신고·반응·댓글·가져가기·카드·글·차단 삭제 > 남의 글 집계 재계산 > 커밋 뒤 그림 삭제
   */
  @Transactional
  public void deleteAllOf(String memberId) {
    // 집계 재계산 대상 (이 회원이 반응·댓글·가져가기를 남긴 남의 글, 지우기 전에 수집)
    List<String> ownPostIds = talkPostRepository.findIdsByAuthorMemberId(memberId);
    Set<String> otherPostIds = new LinkedHashSet<>();
    otherPostIds.addAll(talkHelpfulRepository.findPostIdsHelpfulBy(memberId));
    otherPostIds.addAll(talkCommentRepository.findPostIdsCommentedBy(memberId));
    otherPostIds.addAll(talkImportRepository.findPostIdsImportedBy(memberId));
    otherPostIds.removeAll(ownPostIds);

    // 삭제 (신고는 댓글·글을 가리키므로 먼저, 글은 마지막)
    talkReportRepository.deleteAllInvolving(memberId);
    talkHelpfulRepository.deleteAllOfMemberOrOnPostsOf(memberId);
    talkCommentRepository.deleteAllOfMemberOrOnPostsOf(memberId);
    talkImportRepository.deleteAllOfMemberOrOnPostsOf(memberId);
    talkPostStepRepository.deleteAllByPostAuthor(memberId);
    talkPostRepository.deleteAllByAuthorMemberId(memberId);
    talkBlockRepository.deleteAllInvolving(memberId);

    // 남은 글 집계는 행 수로 다시 셈 (증감이 아님)
    if (!otherPostIds.isEmpty()) {
      talkPostRepository.recountHelpfulCounts(otherPostIds);
      talkPostRepository.recountCommentCounts(otherPostIds);
      talkPostRepository.recountImportCounts(otherPostIds);
    }

    ownPostIds.forEach(this::deleteImagesAfterCommit);
    log.info("[talk cleanup] deleted : posts={}, recounted={}", ownPostIds.size(), otherPostIds.size());
  }

  // 커밋 뒤에만 그림 삭제 (롤백되면 글이 남으므로), 트랜잭션 밖이면 바로
  private void deleteImagesAfterCommit(String postId) {
    if (!TransactionSynchronizationManager.isSynchronizationActive()) {
      deleteImagesQuietly(postId);
      return;
    }
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
      @Override
      public void afterCommit() {
        deleteImagesQuietly(postId);
      }
    });
  }

  private void deleteImagesQuietly(String postId) {
    try {
      talkImageStorage.deletePost(postId);
    } catch (RuntimeException cleanupFailure) {
      log.warn("[talk cleanup] image cleanup failed : postId={}", postId, cleanupFailure);
    }
  }
}
