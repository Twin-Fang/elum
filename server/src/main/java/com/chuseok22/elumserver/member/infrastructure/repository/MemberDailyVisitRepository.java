package com.chuseok22.elumserver.member.infrastructure.repository;

import com.chuseok22.elumserver.common.application.stats.StatsBucketCount;
import com.chuseok22.elumserver.member.core.MemberAccountKind;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberDailyVisit;
import java.time.LocalDate;
import java.util.Collection;
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

  /// 그날 방문 수 (일반 계정만 #1436)
  @Query(value = """
    select count(*) from member_daily_visit v
    join member m on m.id = v.member_id
    where v.visit_date = :visitDate
      and\s""" + MemberAccountKind.COUNTED_MEMBER_SQL, nativeQuery = true)
  long countCountedByVisitDate(@Param("visitDate") LocalDate visitDate);

  /// 방문 기록 시작일 (기록이 없으면 null)
  @Query("select min(v.visitDate) from MemberDailyVisit v")
  LocalDate findFirstVisitDate();

  /// 기간[from, to] 칸별 방문 수 (unit: day, month, 일반 계정만)
  @Query(value = """
    select to_char(date_trunc(cast(:unit as text), v.visit_date), 'YYYY-MM-DD') as bucket, count(*) as total
    from member_daily_visit v
    join member m on m.id = v.member_id
    where v.visit_date between :from and :to
      and\s""" + MemberAccountKind.COUNTED_MEMBER_SQL + """
     group by 1
    """, nativeQuery = true)
  List<StatsBucketCount> countByBucket(
    @Param("unit") String unit, @Param("from") LocalDate from, @Param("to") LocalDate to);

  /// 탈퇴·완전 삭제: 그 회원 방문 기록 전부
  @Modifying(flushAutomatically = true)
  @Query("delete from MemberDailyVisit v where v.memberId = :memberId")
  int deleteAllByMemberId(@Param("memberId") String memberId);

  /// 방문 한 줄 투영: 회원, 방문 날짜
  interface MemberVisitRow {

    String getMemberId();

    LocalDate getVisitDate();
  }

  /// 알림 효과 (#1409): 이 회원들의 since 이후 방문 날짜
  @Query("select v.memberId as memberId, v.visitDate as visitDate from MemberDailyVisit v "
    + "where v.memberId in :memberIds and v.visitDate >= :since")
  List<MemberVisitRow> findVisitsSince(@Param("memberIds") java.util.Collection<String> memberIds,
    @Param("since") LocalDate since);
}
