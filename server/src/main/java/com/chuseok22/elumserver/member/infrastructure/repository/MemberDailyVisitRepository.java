package com.chuseok22.elumserver.member.infrastructure.repository;

import com.chuseok22.elumserver.common.application.stats.StatsBucketCount;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberDailyVisit;
import java.time.LocalDate;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MemberDailyVisitRepository extends JpaRepository<MemberDailyVisit, String> {

  /// 그날 첫 방문만 1줄 (동시 요청이 겹쳐도 고유 제약 위반 없이 무시)
  @Modifying
  @Query(value = """
    insert into member_daily_visit (id, member_id, visit_date, created_at, updated_at)
    values (:id, :memberId, :visitDate, now(), now())
    on conflict (member_id, visit_date) do nothing
    """, nativeQuery = true)
  int insertIfAbsent(
    @Param("id") String id, @Param("memberId") String memberId, @Param("visitDate") LocalDate visitDate);

  long countByVisitDate(LocalDate visitDate);

  /// 기간[from, to] 중복 없는 방문 회원 수
  @Query("""
    select count(distinct v.memberId) from MemberDailyVisit v
    where v.visitDate between :from and :to
    """)
  long countDistinctMembersBetween(@Param("from") LocalDate from, @Param("to") LocalDate to);

  /// 방문 기록 시작일 (기록이 없으면 null)
  @Query("select min(v.visitDate) from MemberDailyVisit v")
  LocalDate findFirstVisitDate();

  /// 기간[from, to] 칸별 방문 수 (unit: day, month)
  @Query(value = """
    select to_char(date_trunc(cast(:unit as text), visit_date), 'YYYY-MM-DD') as bucket, count(*) as total
    from member_daily_visit
    where visit_date between :from and :to
    group by 1
    """, nativeQuery = true)
  List<StatsBucketCount> countByBucket(
    @Param("unit") String unit, @Param("from") LocalDate from, @Param("to") LocalDate to);

  /// 탈퇴·완전 삭제: 그 회원 방문 기록 전부
  @Modifying(clearAutomatically = true, flushAutomatically = true)
  @Query("delete from MemberDailyVisit v where v.memberId = :memberId")
  int deleteAllByMemberId(@Param("memberId") String memberId);
}
