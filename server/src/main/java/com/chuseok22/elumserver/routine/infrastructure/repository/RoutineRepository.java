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

  // 보호자 홈 "지난 일과" — 오늘 이전에 예정됐던 것만 최신순.
  // 지우지 않고 접어두는 이유는 수행률 추이(P1)의 원본 데이터이기 때문이다.
  List<Routine> findAllByMemberIdAndScheduledAtBeforeOrderByScheduledAtDesc(
    String memberId, LocalDateTime before
  );

  // 보호자 홈 "임시저장" — 카드는 만들었지만 아직 아이에게 보내지 않은 일과.
  List<Routine> findAllByMemberIdAndStatusOrderByCreatedAtDesc(
    String memberId, RoutineStatus status
  );

  // 보상 설정 화면의 "최근에 정한 보상" — 같은 보상을 다시 고르는 것이 대부분이라
  // 두 번째 일과부터는 탭 한 번으로 끝나게 한다.
  // 중복 제거·개수 제한은 서비스에서 처리한다 (JPQL distinct는 정렬 컬럼까지 묶여 의도대로 동작하지 않는다).
  List<Routine> findTop30ByMemberIdAndRewardTextIsNotNullOrderByCreatedAtDesc(String memberId);
}
