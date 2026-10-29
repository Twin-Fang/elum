package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPostStep;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface TalkPostStepRepository extends JpaRepository<TalkPostStep, String> {

  List<TalkPostStep> findByPostIdOrderByStepOrderAsc(String postId);

  // 여러 글의 앞쪽 카드 (stepOrder 는 0부터 이어짐)
  List<TalkPostStep> findByPostIdInAndStepOrderLessThanOrderByStepOrderAsc(Collection<String> postIds, int stepOrder);

  Optional<TalkPostStep> findByPostIdAndStepOrder(String postId, int stepOrder);

  // 글 내리기: 그 글의 카드 전부
  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("delete from TalkPostStep s where s.postId = :postId")
  int deleteAllByPostId(@Param("postId") String postId);

  // 탈퇴 정리: 그 회원이 쓴 모든 글의 카드
  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("delete from TalkPostStep s where s.postId in "
    + "(select p.id from TalkPost p where p.authorMemberId = :memberId)")
  int deleteAllByPostAuthor(@Param("memberId") String memberId);
}
