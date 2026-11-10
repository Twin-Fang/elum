package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRejection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RoutineMemoryRejectionRepository extends JpaRepository<RoutineMemoryRejection, String> {

  List<RoutineMemoryRejection> findAllByProfileIdAndMemberId(String profileId, String memberId);

  @Modifying
  @Query("delete from RoutineMemoryRejection rejection where rejection.profileId = :profileId and rejection.memberId = :memberId")
  int deleteAllByOwner(@Param("profileId") String profileId, @Param("memberId") String memberId);
}
