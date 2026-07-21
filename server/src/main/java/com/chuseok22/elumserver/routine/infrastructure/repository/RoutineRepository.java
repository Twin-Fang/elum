package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RoutineRepository extends JpaRepository<Routine, String> {

  List<Routine> findAllByMemberId(String memberId);

  long countByStatus(RoutineStatus status);

  List<Routine> findAllByMemberIdAndStatusInAndScheduledAtBetweenOrderByScheduledAtAsc(
    String memberId, List<RoutineStatus> statuses, LocalDateTime start, LocalDateTime end
  );
}
