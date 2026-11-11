package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryEvidence;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RoutineMemoryEvidenceRepository extends JpaRepository<RoutineMemoryEvidence, String> {

  boolean existsByRuleIdAndRoutineId(String ruleId, String routineId);

  /// 규칙들의 근거 (최근 관찰 먼저). 규칙마다 앞 5개는 부르는 쪽이 자름
  List<RoutineMemoryEvidence> findAllByRuleIdInOrderByObservedAtDesc(Collection<String> ruleIds);

  /// 이 일과가 근거가 된 규칙들의 근거 (방금 고친 일과에서 찾은 것 보기)
  List<RoutineMemoryEvidence> findAllByRoutineId(String routineId);

  @Modifying
  @Query("delete from RoutineMemoryEvidence evidence where evidence.ruleId in :ruleIds")
  int deleteAllByRuleIds(@Param("ruleIds") Collection<String> ruleIds);

  @Modifying
  @Query("""
    delete from RoutineMemoryEvidence evidence where evidence.ruleId in (
      select rule.id from RoutineMemoryRule rule where rule.profileId = :profileId and rule.memberId = :memberId)
    """)
  int deleteAllByOwner(@Param("profileId") String profileId, @Param("memberId") String memberId);
}
