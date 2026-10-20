package com.chuseok22.elumserver.talk.infrastructure.repository;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkBlock;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface TalkBlockRepository extends JpaRepository<TalkBlock, String> {

  List<TalkBlock> findByBlockerMemberId(String blockerMemberId);

  // 차단 목록: 최근 차단이 먼저
  List<TalkBlock> findByBlockerMemberIdOrderByCreatedAtDesc(String blockerMemberId);

  boolean existsByBlockerMemberIdAndBlockedMemberId(String blockerMemberId, String blockedMemberId);
}
