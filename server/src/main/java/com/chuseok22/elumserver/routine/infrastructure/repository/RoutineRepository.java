package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface RoutineRepository extends JpaRepository<Routine, String> {

  List<Routine> findAllByProfileId(String profileId);

  // 회원 목록 화면용 회원별 루틴 개수 집계 — N+1을 피하기 위해 in + group by 한 번에.
  @org.springframework.data.jpa.repository.Query("""
    select r.profile.member.id as memberId, count(r) as routineCount
    from Routine r
    where r.profile.member.id in :memberIds
    group by r.profile.member.id
    """)
  List<MemberRoutineCount> countByMemberIds(
    @org.springframework.data.repository.query.Param("memberIds") List<String> memberIds
  );

  interface MemberRoutineCount {

    String getMemberId();

    long getRoutineCount();
  }

  /** 계정 아래 모든 프로필의 일과. 회원 탈퇴 시 정리용. */
  List<Routine> findAllByProfileMemberId(String memberId);

  /// 계정이 지금 가지고 있는 일과 수. 보유 개수 한도에 쓴다.
  long countByProfileMemberId(String memberId);

  /**
   * 홈 목록용 조회. 보이는 순서 → 예정 시각 차례로 줄 세운다.
   *
   * <p>순서를 한 번도 바꾸지 않았으면 전부 같은 값이라 예정 시각 순이 된다 — 지금
   * 동작과 같다.
   */
  @Query("""
    select r from Routine r
    where r.profile.id = :profileId
      and r.status in :statuses
      and r.scheduledAt between :from and :to
    order by r.displayOrder asc, r.scheduledAt asc
    """)
  List<Routine> findTodayOrdered(
    @Param("profileId") String profileId,
    @Param("statuses") List<RoutineStatus> statuses,
    @Param("from") LocalDateTime from,
    @Param("to") LocalDateTime to
  );

  /// 순서를 새로 매길 때 기준이 되는 값. 새 일과는 이 뒤에 붙는다.
  @Query("select coalesce(max(r.displayOrder), 0) from Routine r where r.profile.id = :profileId")
  int maxDisplayOrder(@Param("profileId") String profileId);

  long countByStatus(RoutineStatus status);

  List<Routine> findAllByProfileIdAndStatusInAndScheduledAtBetweenOrderByScheduledAtAsc(
    String profileId, List<RoutineStatus> statuses, LocalDateTime start, LocalDateTime end
  );

  // 보호자 홈 "지난 일과" — 오늘 이전에 예정됐던 것만 최신순.
  // 지우지 않고 접어두는 이유는 수행률 추이(P1)의 원본 데이터이기 때문이다.
  List<Routine> findAllByProfileIdAndScheduledAtBeforeOrderByScheduledAtDesc(
    String profileId, LocalDateTime before
  );

  // 보호자 홈 "임시저장" — 카드는 만들었지만 아직 아이에게 보내지 않은 일과.
  List<Routine> findAllByProfileIdAndStatusOrderByCreatedAtDesc(
    String profileId, RoutineStatus status
  );

  // 보상 설정 화면의 "최근에 정한 보상" — 같은 보상을 다시 고르는 것이 대부분이라
  // 두 번째 일과부터는 탭 한 번으로 끝나게 한다.
  // 중복 제거·개수 제한은 서비스에서 처리한다 (JPQL distinct는 정렬 컬럼까지 묶여 의도대로 동작하지 않는다).
  List<Routine> findTop30ByProfileIdAndRewardTextIsNotNullOrderByCreatedAtDesc(String profileId);
}
