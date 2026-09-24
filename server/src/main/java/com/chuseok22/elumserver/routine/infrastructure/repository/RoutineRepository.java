package com.chuseok22.elumserver.routine.infrastructure.repository;

import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface RoutineRepository extends JpaRepository<Routine, String> {

  List<Routine> findAllByProfileId(String profileId);

  /**
   * 관리자 목록 검색 (이슈 #248). 제목과 이룸이 호칭으로 찾는다.
   *
   * <p><b>원문({@code rawInputText})은 찾지 않는다.</b> 보호자가 적은 말 그대로라
   * 관리자가 그것으로 검색할 수 있으면 원문을 들여다보는 통로가 된다 (서비스 원칙 5번).
   */
  @Query("""
    select r from Routine r
    where lower(r.title) like lower(concat('%', :keyword, '%'))
       or lower(r.profile.nickname) like lower(concat('%', :keyword, '%'))
    """)
  Page<Routine> searchForAdmin(@Param("keyword") String keyword, Pageable pageable);

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

  /// 이 보호자가 만든 일과 수. 보유 개수 한도에 쓴다 (다중 보호자 E42).
  ///
  /// 이룸이 밑 일과를 세면 함께 돌보는 사람이 만든 일과까지 내 한도를 먹는다. 요금제는 만드는 사람 기준이다.
  long countByCreatedBy(String createdBy);

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
  // 상태로도 거른다 — 임시저장(PENDING_REVIEW)은 이룸이에게 보낸 적이 없어 "지난" 일과가 아니다.
  List<Routine> findAllByProfileIdAndStatusInAndScheduledAtBeforeOrderByScheduledAtDesc(
    String profileId, List<RoutineStatus> statuses, LocalDateTime before
  );

  // 보호자 홈 "임시저장" — 카드는 만들었지만 아직 아이에게 보내지 않은 일과.
  List<Routine> findAllByProfileIdAndStatusOrderByCreatedAtDesc(
    String profileId, RoutineStatus status
  );

  // 보상 설정 화면의 "최근에 정한 보상" — 같은 보상을 다시 고르는 것이 대부분이라
  // 두 번째 일과부터는 탭 한 번으로 끝나게 한다.
  // 중복 제거·개수 제한은 서비스에서 처리한다 (JPQL distinct는 정렬 컬럼까지 묶여 의도대로 동작하지 않는다).
  List<Routine> findTop30ByProfileIdAndRewardTextIsNotNullOrderByCreatedAtDesc(String profileId);

  /**
   * 만든 사람이 비어 있는 일과를 그 프로필의 대표 보호자로 채운다 — V25 의 채우기와 같은 문장이다.
   *
   * <p>새 코드는 항상 채우므로 비어 있으면 옛 서버가 만든 것이다 (E38).
   */
  @Transactional
  @Modifying
  @Query(nativeQuery = true, value = """
    update routine r
    set created_by = (select p.member_id from profile p where p.id = r.profile_id)
    where r.created_by is null
    """)
  int backfillCreatorFromProfileOwner();

  /// 한 이룸이에서 이 보호자가 만든 일과. 나가기가 지운다 (다중 보호자 4-3).
  List<Routine> findAllByProfileIdAndCreatedBy(String profileId, String createdBy);

  /// 이 보호자가 만든 일과 전부. 탈퇴 마지막에 관계 밖에 남은 것을 치운다.
  List<Routine> findAllByCreatedBy(String createdBy);
}
