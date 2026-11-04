package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemory;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RoutineMemoryRepository extends JpaRepository<RoutineMemory, String> {

  Optional<RoutineMemory> findByProfileId(String profileId);

  /// 이룸이 메모 행 지움 (이룸이 삭제·보호자 나가기). 지운 행 수
  @Modifying
  @Query("delete from RoutineMemory memory where memory.profile.id = :profileId")
  int deleteByProfileId(@Param("profileId") String profileId);
}
