package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkImport;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface TalkImportRepository extends JpaRepository<TalkImport, String> {

  boolean existsByPostIdAndMemberId(String postId, String memberId);

  // 탈퇴 정리: 남의 글을 가져간 기록이 반영된 글 id (집계 재계산 대상)
  @Query("select distinct i.postId from TalkImport i where i.memberId = :memberId")
  List<String> findPostIdsImportedBy(@Param("memberId") String memberId);

  // 탈퇴 정리: 그 회원이 가져간 기록과 그 회원의 글을 가져간 기록
  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("delete from TalkImport i where i.memberId = :memberId or i.postId in "
    + "(select p.id from TalkPost p where p.authorMemberId = :memberId)")
  int deleteAllOfMemberOrOnPostsOf(@Param("memberId") String memberId);
}
