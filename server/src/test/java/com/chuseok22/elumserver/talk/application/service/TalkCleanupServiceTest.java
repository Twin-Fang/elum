package com.chuseok22.elumserver.talk.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.talk.infrastructure.repository.TalkBlockRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkCommentRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkHelpfulRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkImportRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostStepRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkReportRepository;
import com.chuseok22.elumserver.talk.infrastructure.storage.TalkImageStorage;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/// 탈퇴 정리: 남은 그림·신고·차단, 남의 글에 남은 낡은 집계, 롤백됐는데 지워진 그림을 막는다.
@ExtendWith(MockitoExtension.class)
class TalkCleanupServiceTest {

  private static final String MEMBER_ID = "member-1";

  @Mock
  private TalkPostRepository talkPostRepository;
  @Mock
  private TalkPostStepRepository talkPostStepRepository;
  @Mock
  private TalkCommentRepository talkCommentRepository;
  @Mock
  private TalkHelpfulRepository talkHelpfulRepository;
  @Mock
  private TalkImportRepository talkImportRepository;
  @Mock
  private TalkReportRepository talkReportRepository;
  @Mock
  private TalkBlockRepository talkBlockRepository;
  @Mock
  private TalkImageStorage talkImageStorage;

  @InjectMocks
  private TalkCleanupService talkCleanupService;

  @AfterEach
  void clearSynchronization() {
    if (TransactionSynchronizationManager.isSynchronizationActive()) {
      TransactionSynchronizationManager.clearSynchronization();
    }
  }

  @Test
  @DisplayName("회원의 글·카드·댓글·반응·신고·차단·가져가기를 지우고 남의 글 집계를 다시 센다")
  void deleteAllOf_removesOwnContent_andRecountsOthers() {
    when(talkPostRepository.findIdsByAuthorMemberId(MEMBER_ID)).thenReturn(List.of("own-1", "own-2"));
    // 내 글에도 단 댓글(own-1)은 재계산 대상이 아니다 (글째로 지워짐)
    when(talkHelpfulRepository.findPostIdsHelpfulBy(MEMBER_ID)).thenReturn(List.of("other-1", "own-1"));
    when(talkCommentRepository.findPostIdsCommentedBy(MEMBER_ID)).thenReturn(List.of("other-2"));
    when(talkImportRepository.findPostIdsImportedBy(MEMBER_ID)).thenReturn(List.of("other-1", "other-3"));

    talkCleanupService.deleteAllOf(MEMBER_ID);

    // 신고가 댓글·글을 가리키므로 먼저, 글은 카드 뒤
    InOrder deleteOrder = inOrder(talkReportRepository, talkHelpfulRepository, talkCommentRepository,
      talkImportRepository, talkPostStepRepository, talkPostRepository, talkBlockRepository);
    deleteOrder.verify(talkReportRepository).deleteAllInvolving(MEMBER_ID);
    deleteOrder.verify(talkHelpfulRepository).deleteAllOfMemberOrOnPostsOf(MEMBER_ID);
    deleteOrder.verify(talkCommentRepository).deleteAllOfMemberOrOnPostsOf(MEMBER_ID);
    deleteOrder.verify(talkImportRepository).deleteAllOfMemberOrOnPostsOf(MEMBER_ID);
    deleteOrder.verify(talkPostStepRepository).deleteAllByPostAuthor(MEMBER_ID);
    deleteOrder.verify(talkPostRepository).deleteAllByAuthorMemberId(MEMBER_ID);
    deleteOrder.verify(talkBlockRepository).deleteAllInvolving(MEMBER_ID);

    // 남의 글 3개만 세 집계를 다시 센다
    ArgumentCaptor<java.util.Collection<String>> helpfulIds = ArgumentCaptor.forClass(java.util.Collection.class);
    ArgumentCaptor<java.util.Collection<String>> commentIds = ArgumentCaptor.forClass(java.util.Collection.class);
    ArgumentCaptor<java.util.Collection<String>> importIds = ArgumentCaptor.forClass(java.util.Collection.class);
    verify(talkPostRepository).recountHelpfulCounts(helpfulIds.capture());
    verify(talkPostRepository).recountCommentCounts(commentIds.capture());
    verify(talkPostRepository).recountImportCounts(importIds.capture());
    assertThat(Set.copyOf(helpfulIds.getValue())).containsExactlyInAnyOrder("other-1", "other-2", "other-3");
    assertThat(Set.copyOf(commentIds.getValue())).containsExactlyInAnyOrder("other-1", "other-2", "other-3");
    assertThat(Set.copyOf(importIds.getValue())).containsExactlyInAnyOrder("other-1", "other-2", "other-3");

    // 트랜잭션 밖이면 그림을 바로 지움
    verify(talkImageStorage).deletePost("own-1");
    verify(talkImageStorage).deletePost("own-2");
  }

  @Test
  @DisplayName("반응·댓글이 없으면 집계 재계산을 건너뛴다")
  void deleteAllOf_skipsRecountWhenNothingToRecount() {
    when(talkPostRepository.findIdsByAuthorMemberId(MEMBER_ID)).thenReturn(List.of());

    talkCleanupService.deleteAllOf(MEMBER_ID);

    verify(talkPostRepository, never()).recountHelpfulCounts(any());
    verify(talkPostRepository, never()).recountCommentCounts(any());
    verify(talkPostRepository, never()).recountImportCounts(any());
    verifyNoInteractions(talkImageStorage);
  }

  @Test
  @DisplayName("트랜잭션 안에서는 커밋 뒤에만 그림을 지우고, 그림 삭제가 실패해도 탈퇴는 이어진다")
  void deleteAllOf_deletesImagesOnlyAfterCommit_andSwallowsStorageFailure() {
    when(talkPostRepository.findIdsByAuthorMemberId(MEMBER_ID)).thenReturn(List.of("own-1"));
    doThrow(new RuntimeException("disk")).when(talkImageStorage).deletePost("own-1");
    TransactionSynchronizationManager.initSynchronization();

    talkCleanupService.deleteAllOf(MEMBER_ID);

    verifyNoInteractions(talkImageStorage);
    assertThatCode(() -> TransactionSynchronizationManager.getSynchronizations()
      .forEach(TransactionSynchronization::afterCommit)).doesNotThrowAnyException();
    verify(talkImageStorage).deletePost("own-1");
  }
}
