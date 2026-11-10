package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRule;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RoutineMemoryRuleRepository extends JpaRepository<RoutineMemoryRule, String> {

  List<RoutineMemoryRule> findAllByProfileIdAndMemberId(String profileId, String memberId);

  Optional<RoutineMemoryRule> findByIdAndProfileIdAndMemberId(String id, String profileId, String memberId);

  List<RoutineMemoryRule> findAllByIdInAndProfileIdAndMemberId(Collection<String> ids, String profileId, String memberId);

  List<RoutineMemoryRule> findAllByProfileIdAndMemberIdAndStatus(
    String profileId, String memberId, RoutineMemoryRuleStatus status);

  long countByProfileIdAndMemberId(String profileId, String memberId);

  /// (이룸이, 보호자)의 규칙 모두 지움. 지운 행 수 (근거는 DB 의 ON DELETE CASCADE 와 아래 근거 삭제가 함께 치움)
  @Modifying
  @Query("delete from RoutineMemoryRule rule where rule.profileId = :profileId and rule.memberId = :memberId")
  int deleteAllByOwner(@Param("profileId") String profileId, @Param("memberId") String memberId);
}
