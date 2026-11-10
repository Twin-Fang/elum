package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.routine.infrastructure.entity.WeeklyReportSummary;
import java.time.LocalDate;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface WeeklyReportSummaryRepository extends JpaRepository<WeeklyReportSummary, String> {

  @Query("""
    select s from WeeklyReportSummary s
    where s.profile.id = :profileId and s.weekStart = :weekStart and s.language = :language
    """)
  Optional<WeeklyReportSummary> findOne(
    @Param("profileId") String profileId, @Param("weekStart") LocalDate weekStart, @Param("language") String language);

  /// 이룸이 정리 글 전부 지움 (이룸이 삭제·보호자 나가기). 지운 행 수
  @Modifying
  @Query("delete from WeeklyReportSummary s where s.profile.id = :profileId")
  int deleteByProfileId(@Param("profileId") String profileId);
}
