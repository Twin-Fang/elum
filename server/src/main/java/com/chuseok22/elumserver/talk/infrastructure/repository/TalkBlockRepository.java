package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkBlock;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface TalkBlockRepository extends JpaRepository<TalkBlock, String> {

  List<TalkBlock> findByBlockerMemberId(String blockerMemberId);

  // 차단 목록: 최근 차단이 먼저
  List<TalkBlock> findByBlockerMemberIdOrderByCreatedAtDesc(String blockerMemberId);

  boolean existsByBlockerMemberIdAndBlockedMemberId(String blockerMemberId, String blockedMemberId);

  // 탈퇴 정리: 차단한 것과 차단당한 것 양쪽
  @Transactional
  @Modifying(flushAutomatically = true)
  @Query("delete from TalkBlock b where b.blockerMemberId = :memberId or b.blockedMemberId = :memberId")
  int deleteAllInvolving(@Param("memberId") String memberId);
}
