package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.core.TalkCommentStatus;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkComment;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface TalkCommentRepository extends JpaRepository<TalkComment, String> {

  /**
   * 댓글 한 쪽: 오래된 순 (쓴 시각 오름, id 오름), cursor 위치보다 뒤
   * cursor 없음은 아주 이른 시각과 빈 id 를 넘김
   */
  @Query("select c from TalkComment c where c.postId = :postId and c.status = :status "
    + "and (c.createdAt > :cursorCreatedAt or (c.createdAt = :cursorCreatedAt and c.id > :cursorId)) "
    + "order by c.createdAt asc, c.id asc")
  List<TalkComment> findCommentPage(
    @Param("postId") String postId, @Param("status") TalkCommentStatus status,
    @Param("cursorCreatedAt") LocalDateTime cursorCreatedAt, @Param("cursorId") String cursorId,
    Pageable pageable);

  // 보이는 댓글만 DELETED 로 바꾸고 본문을 비움 (바꾼 건수: 이미 지워졌으면 0, 동시에 두 번 눌러도 한 번만 1)
  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("update TalkComment c set c.status = :deletedStatus, c.body = '' "
    + "where c.id = :commentId and c.status = :visibleStatus")
  int updateStatusIfVisible(@Param("commentId") String commentId, @Param("deletedStatus") TalkCommentStatus deletedStatus,
    @Param("visibleStatus") TalkCommentStatus visibleStatus);

  // 관리자 상세: 모든 상태의 댓글, 오래된 순
  List<TalkComment> findByPostIdOrderByCreatedAtAscIdAsc(String postId);

  // 상태 전환: 지금 상태가 expected 일 때만 바꿈 (바꾼 건수: 이미 바뀌었거나 지워진 댓글이면 0)
  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("update TalkComment c set c.status = :nextStatus where c.id = :commentId and c.status = :expectedStatus")
  int updateStatusIfCurrent(@Param("commentId") String commentId, @Param("nextStatus") TalkCommentStatus nextStatus,
    @Param("expectedStatus") TalkCommentStatus expectedStatus);

  // 탈퇴 정리: 남의 글에 단 댓글이 반영된 글 id (집계 재계산 대상)
  @Query("select distinct c.postId from TalkComment c where c.authorMemberId = :memberId")
  List<String> findPostIdsCommentedBy(@Param("memberId") String memberId);

  // 탈퇴 정리: 그 회원이 쓴 댓글과 그 회원의 글에 달린 댓글
  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("delete from TalkComment c where c.authorMemberId = :memberId or c.postId in "
    + "(select p.id from TalkPost p where p.authorMemberId = :memberId)")
  int deleteAllOfMemberOrOnPostsOf(@Param("memberId") String memberId);
}
