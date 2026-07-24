package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface RoutineRepository extends JpaRepository<Routine, String> {

  List<Routine> findAllByMemberId(String memberId);

  // 회원 목록 화면용 회원별 루틴 개수 집계 — N+1을 피하기 위해 in + group by 한 번에.
  @org.springframework.data.jpa.repository.Query("""
    select r.member.id as memberId, count(r) as routineCount
    from Routine r
    where r.member.id in :memberIds
    group by r.member.id
    """)
  List<MemberRoutineCount> countByMemberIds(
    @org.springframework.data.repository.query.Param("memberIds") List<String> memberIds
  );

  interface MemberRoutineCount {

    String getMemberId();

    long getRoutineCount();
  }

  long countByStatus(RoutineStatus status);

  List<Routine> findAllByMemberIdAndStatusInAndScheduledAtBetweenOrderByScheduledAtAsc(
    String memberId, List<RoutineStatus> statuses, LocalDateTime start, LocalDateTime end
  );
}
