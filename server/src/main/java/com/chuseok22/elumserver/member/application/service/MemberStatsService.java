package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.common.application.stats.StatsBucketCount;
import com.chuseok22.elumserver.common.application.stats.StatsBucketUnit;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberDailyVisitRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 회원 통계: 가입·탈퇴·방문 칸별 건수, 지금 접속 중, 오늘·기간 방문 수
 * 칸 채우기(빈 날 0)는 부르는 쪽(관리자 추이) 책임
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MemberStatsService {

  /// 지금 접속 중 기준 (최근 5분 활동, 활동 시각이 60초마다 갱신돼 근사값)
  public static final int ONLINE_WITHIN_MINUTES = 5;

  private final MemberRepository memberRepository;
  private final MemberDailyVisitRepository memberDailyVisitRepository;

  /** 기간[from, to] 칸별 가입 수 */
  public List<StatsBucketCount> countJoinedByBucket(StatsBucketUnit unit, LocalDate from, LocalDate toInclusive) {
    return memberRepository.countJoinedByBucket(unit.sqlName(), from.atStartOfDay(), toInclusive.plusDays(1).atStartOfDay());
  }

  /** 기간[from, to] 칸별 탈퇴 수 */
  public List<StatsBucketCount> countWithdrawnByBucket(StatsBucketUnit unit, LocalDate from, LocalDate toInclusive) {
    return memberRepository.countWithdrawnByBucket(unit.sqlName(), from.atStartOfDay(), toInclusive.plusDays(1).atStartOfDay());
  }

  /** 기간[from, to] 칸별 방문 수 */
  public List<StatsBucketCount> countVisitsByBucket(StatsBucketUnit unit, LocalDate from, LocalDate toInclusive) {
    return memberDailyVisitRepository.countByBucket(unit.sqlName(), from, toInclusive);
  }

  /** 방문 기록 시작일 (없으면 null — 그 전 날짜는 그래프에서 빈칸) */
  public LocalDate findVisitTrackingStartDate() {
    return memberDailyVisitRepository.findFirstVisitDate();
  }

  /** 지금 접속 중 (최근 5분 활동, 탈퇴 제외) */
  public long countOnline(LocalDateTime now) {
    return memberRepository.countByLastActivityAtAfterAndStatusNot(
      now.minusMinutes(ONLINE_WITHIN_MINUTES), MemberStatus.WITHDRAWN);
  }

  public long countVisitsOn(LocalDate date) {
    return memberDailyVisitRepository.countByVisitDate(date);
  }

  /** 기간[from, to] 중복 없는 방문 회원 수 */
  public long countDistinctVisitorsBetween(LocalDate from, LocalDate toInclusive) {
    return memberDailyVisitRepository.countDistinctMembersBetween(from, toInclusive);
  }

  public long countJoinedOn(LocalDate date) {
    return memberRepository.countByCreatedAtGreaterThanEqualAndCreatedAtLessThan(
      date.atStartOfDay(), date.plusDays(1).atStartOfDay());
  }
}
