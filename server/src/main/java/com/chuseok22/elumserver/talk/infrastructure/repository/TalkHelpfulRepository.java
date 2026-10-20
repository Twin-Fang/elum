package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkHelpful;
import java.util.List;
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

  // 탈퇴 정리: 남의 글에 누른 도움돼요가 반영된 글 id (집계 재계산 대상)
  @Query("select distinct h.postId from TalkHelpful h where h.memberId = :memberId")
  List<String> findPostIdsHelpfulBy(@Param("memberId") String memberId);

  // 탈퇴 정리: 그 회원이 누른 것과 그 회원의 글에 눌린 것
  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("delete from TalkHelpful h where h.memberId = :memberId or h.postId in "
    + "(select p.id from TalkPost p where p.authorMemberId = :memberId)")
  int deleteAllOfMemberOrOnPostsOf(@Param("memberId") String memberId);
}
