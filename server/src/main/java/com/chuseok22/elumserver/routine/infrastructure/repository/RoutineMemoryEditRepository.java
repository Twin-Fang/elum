package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryEdit;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RoutineMemoryEditRepository extends JpaRepository<RoutineMemoryEdit, String> {

  Optional<RoutineMemoryEdit> findByRoutineId(String routineId);

  boolean existsByRoutineId(String routineId);

  /// 최근 수정 기록 (호출부가 페이지 크기로 20개만)
  List<RoutineMemoryEdit> findAllByProfileIdAndMemberIdOrderByEditedAtDesc(
    String profileId, String memberId, Pageable pageable);

  @Modifying
  @Query("delete from RoutineMemoryEdit edit where edit.profileId = :profileId and edit.memberId = :memberId")
  int deleteAllByOwner(@Param("profileId") String profileId, @Param("memberId") String memberId);
}
