package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineGroup;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RoutineGroupRepository extends JpaRepository<RoutineGroup, String> {

  /// 일과관리 묶음 목록: 묶음 순서 > 만든 차례 (#806)
  List<RoutineGroup> findAllByProfileIdOrderByDisplayOrderAscCreatedAtAsc(String profileId);

  /// 새 묶음 순서의 기준. 묶음이 없으면 -1 (첫 묶음이 0)
  @Query("select coalesce(max(g.displayOrder), -1) from RoutineGroup g where g.profile.id = :profileId")
  int maxDisplayOrder(@Param("profileId") String profileId);
}
