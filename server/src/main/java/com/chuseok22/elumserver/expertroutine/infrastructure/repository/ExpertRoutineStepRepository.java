package com.chuseok22.elumserver.expertroutine.infrastructure.repository;

import com.chuseok22.elumserver.expertroutine.infrastructure.entity.ExpertRoutineStep;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ExpertRoutineStepRepository extends JpaRepository<ExpertRoutineStep, String> {

  List<ExpertRoutineStep> findByExpertRoutineIdOrderByStepOrderAsc(String expertRoutineId);

  /// 목록 그림용: 여러 일과의 같은 순서 카드 (보통 첫 카드 0)
  List<ExpertRoutineStep> findByExpertRoutineIdInAndStepOrder(Collection<String> expertRoutineIds, int stepOrder);

  /// 카드 전부 지우기 (고칠 때 통째로 바꿈, 지울 때 함께 지움)
  @Modifying(flushAutomatically = true)
  @Query("delete from ExpertRoutineStep step where step.expertRoutineId = :expertRoutineId")
  int deleteByExpertRoutineId(@Param("expertRoutineId") String expertRoutineId);
}
