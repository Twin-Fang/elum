package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.core.TalkCommentStatus;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkComment;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

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
}
