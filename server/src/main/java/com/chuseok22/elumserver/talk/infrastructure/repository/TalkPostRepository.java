package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface TalkPostRepository extends JpaRepository<TalkPost, String> {

  // 같은 원본으로 올린 글이 이미 있는가 (원본 하나당 보이는 글은 하나)
  boolean existsBySourceRoutineIdAndStatus(String sourceRoutineId, TalkPostStatus status);

  // 내가 올린 보이는 글 (원본 일과 > 글 매핑용)
  List<TalkPost> findByAuthorMemberIdAndStatus(String authorMemberId, TalkPostStatus status);

  /**
   * 피드 한 쪽: 최신순 (올린 시각 내림, id 내림), cursor 위치보다 뒤
   * 분류 전체는 호출부가 6개를 모두 넘김, cursor 없음은 먼 미래 시각을 넘김
   */
  @Query("select p from TalkPost p where p.status = :status and p.language = :language "
    + "and p.category in :categories "
    + "and (p.createdAt < :cursorCreatedAt or (p.createdAt = :cursorCreatedAt and p.id < :cursorId)) "
    + "order by p.createdAt desc, p.id desc")
  List<TalkPost> findFeedPage(
    @Param("status") TalkPostStatus status, @Param("language") AppLocale language,
    @Param("categories") Collection<TalkCategory> categories,
    @Param("cursorCreatedAt") LocalDateTime cursorCreatedAt, @Param("cursorId") String cursorId,
    Pageable pageable);

  /**
   * 인기 글 id: since 이후 가져간 고유 보호자 수 내림차순 (같으면 최신순, 시각도 같으면 id 큰 순), 가져간 기록 없는 글은 빠짐
   */
  @Query("select p.id from TalkPost p, TalkImport i where i.postId = p.id and p.status = :status "
    + "and p.language = :language and p.category in :categories and i.createdAt >= :since "
    + "group by p.id, p.createdAt order by count(distinct i.memberId) desc, p.createdAt desc, p.id desc")
  List<String> findPopularPostIds(
    @Param("status") TalkPostStatus status, @Param("language") AppLocale language,
    @Param("categories") Collection<TalkCategory> categories, @Param("since") LocalDateTime since,
    Pageable pageable);

  // 집계 증감: 동시에 눌려도 값이 겹쳐 쓰이지 않게 DB 에서 바로 더하고, 줄일 때는 0 아래로 내려가지 않게 막음
  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("update TalkPost p set p.helpfulCount = p.helpfulCount + 1 where p.id = :postId")
  int increaseHelpfulCount(@Param("postId") String postId);

  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("update TalkPost p set p.helpfulCount = p.helpfulCount - 1 where p.id = :postId and p.helpfulCount > 0")
  int decreaseHelpfulCount(@Param("postId") String postId);

  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("update TalkPost p set p.commentCount = p.commentCount + 1 where p.id = :postId")
  int increaseCommentCount(@Param("postId") String postId);

  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("update TalkPost p set p.commentCount = p.commentCount - 1 where p.id = :postId and p.commentCount > 0")
  int decreaseCommentCount(@Param("postId") String postId);

  /**
   * 관리자 글 목록: 상태 필터, 제목 검색 (정렬은 Pageable)
   * 검색어는 호출부가 이스케이프한 LIKE 패턴으로 넘김 (ESCAPE '\\'), hasKeyword 가 false 면 pattern 을 보지 않음
   */
  @Query(value = "select p from TalkPost p where p.status in :statuses "
    + "and (:hasKeyword = false or lower(p.title) like lower(:pattern) escape '\\')",
    countQuery = "select count(p) from TalkPost p where p.status in :statuses "
      + "and (:hasKeyword = false or lower(p.title) like lower(:pattern) escape '\\')")
  Page<TalkPost> searchForAdmin(
    @Param("hasKeyword") boolean hasKeyword, @Param("pattern") String pattern,
    @Param("statuses") Collection<TalkPostStatus> statuses, Pageable pageable);

  // 관리자 글 목록, 미처리 신고(글·댓글 합산) 많은 순 (같으면 최신순, id 로 고정). Pageable 은 정렬 없이 넘김
  @Query(value = "select p from TalkPost p where p.status in :statuses "
    + "and (:hasKeyword = false or lower(p.title) like lower(:pattern) escape '\\') "
    + "order by (select count(r) from TalkReport r where r.postId = p.id and r.resolvedAt is null) desc, "
    + "p.createdAt desc, p.id asc",
    countQuery = "select count(p) from TalkPost p where p.status in :statuses "
      + "and (:hasKeyword = false or lower(p.title) like lower(:pattern) escape '\\')")
  Page<TalkPost> searchForAdminByUnresolvedReportsDescending(
    @Param("hasKeyword") boolean hasKeyword, @Param("pattern") String pattern,
    @Param("statuses") Collection<TalkPostStatus> statuses, Pageable pageable);

  // 미처리 신고 적은 순
  @Query(value = "select p from TalkPost p where p.status in :statuses "
    + "and (:hasKeyword = false or lower(p.title) like lower(:pattern) escape '\\') "
    + "order by (select count(r) from TalkReport r where r.postId = p.id and r.resolvedAt is null) asc, "
    + "p.createdAt desc, p.id asc",
    countQuery = "select count(p) from TalkPost p where p.status in :statuses "
      + "and (:hasKeyword = false or lower(p.title) like lower(:pattern) escape '\\')")
  Page<TalkPost> searchForAdminByUnresolvedReportsAscending(
    @Param("hasKeyword") boolean hasKeyword, @Param("pattern") String pattern,
    @Param("statuses") Collection<TalkPostStatus> statuses, Pageable pageable);

  // 상태 전환: 지금 상태가 expected 일 때만 바꿈 (바꾼 건수: 이미 바뀌었거나 지워진 글이면 0)
  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("update TalkPost p set p.status = :nextStatus where p.id = :postId and p.status = :expectedStatus")
  int updateStatusIfCurrent(@Param("postId") String postId, @Param("nextStatus") TalkPostStatus nextStatus,
    @Param("expectedStatus") TalkPostStatus expectedStatus);
}
