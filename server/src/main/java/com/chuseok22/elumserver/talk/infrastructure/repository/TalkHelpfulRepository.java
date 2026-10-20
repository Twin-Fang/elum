package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkHelpful;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface TalkHelpfulRepository extends JpaRepository<TalkHelpful, String> {

  boolean existsByPostIdAndMemberId(String postId, String memberId);

  // 지운 건수 (0 이면 누른 적 없음)
  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("delete from TalkHelpful h where h.postId = :postId and h.memberId = :memberId")
  int deleteByPostIdAndMemberId(@Param("postId") String postId, @Param("memberId") String memberId);
}
