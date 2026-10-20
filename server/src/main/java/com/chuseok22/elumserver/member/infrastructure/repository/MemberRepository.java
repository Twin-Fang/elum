package com.chuseok22.elumserver.member.infrastructure.repository;

import com.chuseok22.elumserver.common.application.stats.StatsBucketCount;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface MemberRepository extends JpaRepository<Member, String> {

  boolean existsByUsername(String username);

  boolean existsByNickname(String nickname);

  // 보호자 닉네임 변경: 대소문자 무시, 본인 제외
  boolean existsByNicknameIgnoreCaseAndIdNot(String nickname, String id);

  /** 닉네임이 없는 계정 (V46 이전 가입자). 기동 시 일괄 채움용 */
  List<Member> findAllByNicknameIsNull();

  /**
   * 계정 행을 잠그고 읽는다. 같은 보호자의 새 이룸이 만들기가 겹칠 때 차례로 줄 세우려는 것이다 —
   * 아직 없는 이룸이는 잠글 행이 없어서, 이 보호자의 계정 행을 대신 잠근다.
   */
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select m from Member m where m.id = :id")
  Optional<Member> findByIdForUpdate(@Param("id") String id);

  Optional<Member> findByUsername(String username);

  /**
   * 관리자 회원 목록: 상태 · 검색어(아이디 또는 이룸이 호칭) · 지금 유효한 요금제로 거른다.
   *
   * <p>요금제는 {@code Subscription.effectivePlan} 과 같은 기준(ACTIVE · 만료 전 PRO)이다. 구독을 그 조건으로
   * left join 하므로 s 가 있으면 지금 PRO, 없으면 FREE(구독 행이 없는 회원 포함)이고 정렬 "s.plan" 도 같은 기준이 된다
   * (회원당 구독은 최대 1행). 검색어는 호출부가
   * {@code AdminListQuery.likePattern()} 으로 이스케이프해 넘긴다.
   * 한 보호자에 이룸이가 여럿이어도 중복되지 않도록 이룸이 호칭은 join 대신 exists 를 쓴다.
   *
   * @param hasKeyword  false 면 pattern 을 보지 않는다 (null 파라미터 타입 추론 문제를 피하려고 따로 받음)
   * @param planFilter  ALL, PRO, FREE
   * @param joinedFrom  가입일 기간 시작(포함). 필터가 없으면 아주 이른 날 (null 바인딩을 피하려고 늘 값을 넣음)
   */
  @Query("""
    select m from Member m
    left join Subscription s on s.member = m
      and s.plan = com.chuseok22.elumserver.license.core.PlanType.PRO
      and s.status = com.chuseok22.elumserver.license.core.SubscriptionStatus.ACTIVE
      and (s.expiresAt is null or s.expiresAt >= :now)
    where m.status in :statuses
      and m.createdAt >= :joinedFrom and m.createdAt < :joinedToExclusive
      and (:hasKeyword = false
        or lower(m.username) like lower(:pattern) escape '\\'
        or exists (
          select 1 from ProfileGuardian g
          where g.member = m
            and lower(g.profile.nickname) like lower(:pattern) escape '\\'
        ))
      and (:planFilter = 'ALL'
        or (:planFilter = 'PRO' and s.id is not null)
        or (:planFilter = 'FREE' and s.id is null))
    """)
  Page<Member> searchForAdmin(
    @Param("hasKeyword") boolean hasKeyword, @Param("pattern") String pattern,
    @Param("statuses") Collection<MemberStatus> statuses, @Param("planFilter") String planFilter,
    @Param("now") LocalDateTime now, @Param("joinedFrom") LocalDateTime joinedFrom,
    @Param("joinedToExclusive") LocalDateTime joinedToExclusive, Pageable pageable
  );

  long countByStatus(MemberStatus status);

  // --- 탈퇴 계정 ---
  // 탈퇴해도 행이 남으므로, 탈퇴 전처럼 "회원"을 세고 보여주려면 WITHDRAWN 을 빼야 한다.

  long countByStatusNot(MemberStatus status);

  long countByLastActivityAtAfterAndStatusNot(LocalDateTime after, MemberStatus status);

  /**
   * 보관 기간이 지난 탈퇴 계정. 완전 삭제 스케줄러가 쓴다.
   *
   * <p>탈퇴 시각이 비어 있는 탈퇴 계정도 고른다 — 언제 탈퇴했는지 모르면 보관 기간 안이라고
   * 말할 수 없다.
   */
  @Query("""
    select m.id from Member m
    where m.status = :status
      and (m.withdrawnAt is null or m.withdrawnAt <= :threshold)
    """)
  List<String> findWithdrawnIdsUntil(
    @Param("status") MemberStatus status, @Param("threshold") LocalDateTime threshold
  );

  /**
   * 관리자 크레딧 회원 검색 — 회원 id 그대로 · 아이디 · 이룸이 호칭 일부로 찾는다.
   *
   * <p>크레딧 표는 계정 단위라 회원 목록처럼 Member 를 페이지로 받지 않는다. 맞는 id 만 받아 계정 쪽에서 거른다.
   */
  @Query("""
    select m.id from Member m
    where m.id = :keyword
       or lower(m.username) like lower(concat('%', :keyword, '%'))
       or exists (
         select 1 from ProfileGuardian g
         where g.member = m
           and lower(g.profile.nickname) like lower(concat('%', :keyword, '%'))
       )
    """)
  List<String> findIdsByKeyword(@Param("keyword") String keyword);

  // 최근 활동 회원수(대시보드) — lastActivityAt 기준.
  long countByLastActivityAtAfter(LocalDateTime after);

  /// 기간[from, to) 가입 수 (탈퇴 회원 포함 — 그날 가입한 사실은 남음)
  long countByCreatedAtGreaterThanEqualAndCreatedAtLessThan(LocalDateTime from, LocalDateTime to);

  /// 기간[from, to) 칸별 가입 수 (unit: day, month)
  @Query(value = """
    select to_char(date_trunc(cast(:unit as text), created_at), 'YYYY-MM-DD') as bucket, count(*) as total
    from member
    where created_at >= :from and created_at < :to
    group by 1
    """, nativeQuery = true)
  List<StatsBucketCount> countJoinedByBucket(
    @Param("unit") String unit, @Param("from") LocalDateTime from, @Param("to") LocalDateTime to);

  /// 기간[from, to) 칸별 탈퇴 수 (되살린 계정은 탈퇴 시각이 비어 빠짐)
  @Query(value = """
    select to_char(date_trunc(cast(:unit as text), withdrawn_at), 'YYYY-MM-DD') as bucket, count(*) as total
    from member
    where withdrawn_at >= :from and withdrawn_at < :to
    group by 1
    """, nativeQuery = true)
  List<StatsBucketCount> countWithdrawnByBucket(
    @Param("unit") String unit, @Param("from") LocalDateTime from, @Param("to") LocalDateTime to);
}
