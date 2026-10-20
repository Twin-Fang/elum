package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

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
}
