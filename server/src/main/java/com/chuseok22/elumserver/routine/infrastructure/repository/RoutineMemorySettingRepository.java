package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemorySetting;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RoutineMemorySettingRepository extends JpaRepository<RoutineMemorySetting, String> {

  Optional<RoutineMemorySetting> findByProfileIdAndMemberId(String profileId, String memberId);

  @Modifying
  @Query("delete from RoutineMemorySetting setting where setting.profileId = :profileId and setting.memberId = :memberId")
  int deleteAllByOwner(@Param("profileId") String profileId, @Param("memberId") String memberId);
}
