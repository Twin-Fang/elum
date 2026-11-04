package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineSchedule;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RoutineScheduleRepository extends JpaRepository<RoutineSchedule, String> {

  Optional<RoutineSchedule> findByRoutineId(String routineId);

  List<RoutineSchedule> findAllByProfileId(String profileId);

  /// 1분마다: 이 시각 구간(양 끝 포함)에 걸린 예약 (요일은 부르는 쪽이 거름)
  List<RoutineSchedule> findAllByTimeOfDayBetween(LocalTime from, LocalTime to);

  void deleteByRoutineId(String routineId);

  /**
   * 오늘 일과 만들기 차지: 그날 아직 안 만들었을 때만 날짜를 적고 1, 아니면 0
   * 행 잠금으로 동시 요청(이룸이 조회 · 1분 작업 · 서버 둘)이 겹쳐도 한 번만 1
   */
  @Modifying(flushAutomatically = true)
  @Query("""
    update RoutineSchedule s set s.lastMaterializedDate = :today
    where s.id = :id and (s.lastMaterializedDate is null or s.lastMaterializedDate < :today)
    """)
  int claimMaterialization(@Param("id") String id, @Param("today") LocalDate today);

  /// 알림 보내기 차지: 그날 아직 안 보냈을 때만 날짜를 적고 1, 아니면 0 (차지 방식은 위와 같음)
  @Modifying(flushAutomatically = true)
  @Query("""
    update RoutineSchedule s set s.lastNotifiedDate = :today
    where s.id = :id and (s.lastNotifiedDate is null or s.lastNotifiedDate < :today)
    """)
  int claimNotification(@Param("id") String id, @Param("today") LocalDate today);
}
