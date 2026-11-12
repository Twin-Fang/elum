package com.chuseok22.elumserver.notification.infrastructure.repository;

import com.chuseok22.elumserver.notification.core.ScheduledAdminPushStatus;
import com.chuseok22.elumserver.notification.infrastructure.entity.ScheduledAdminPush;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

public interface ScheduledAdminPushRepository extends JpaRepository<ScheduledAdminPush, String> {

  /// member_ids 구분자 (AdminScheduledPushService 가 쓰는 값과 같음)
  String MEMBER_ID_DELIMITER = ",";

  /// 대상 회원 id 목록(쉼표 구분)에 이 회원이 들어 있는 예약 (후보, 정확한 판정은 [#deleteMemberFromTargets])
  List<ScheduledAdminPush> findByMemberIdsContaining(String memberId);

  /// 탈퇴·완전 삭제한 회원을 예약 대상 목록에서 빼기 (예약 행은 운영 기록이라 남김, #1307)
  /// 쉼표 목록을 나눠 같은 id 만 뺌 (다른 id 의 일부와 겹쳐도 지우지 않게). 호출부 트랜잭션 안에서 변경 감지로 저장
  default void deleteMemberFromTargets(String memberId) {
    for (ScheduledAdminPush scheduled : findByMemberIdsContaining(memberId)) {
      List<String> remaining = Arrays.stream(scheduled.getMemberIds().split(MEMBER_ID_DELIMITER))
        .map(String::strip)
        .filter(id -> !id.isEmpty() && !id.equals(memberId))
        .toList();
      scheduled.setMemberIds(String.join(MEMBER_ID_DELIMITER, remaining));
    }
  }

  /// 관리자 목록: 보낼 시각 최신순
  List<ScheduledAdminPush> findAllByOrderByScheduledAtDesc(Pageable pageable);

  /// 보낼 시각이 지난 기다림 id (오래된 순)
  @Query("""
    select p.id from ScheduledAdminPush p
    where p.status = :status and p.scheduledAt <= :now
    order by p.scheduledAt asc
    """)
  List<String> findIdsDue(@Param("status") ScheduledAdminPushStatus status, @Param("now") LocalDateTime now);

  /// 상태 바꾸기: from 상태일 때만 to 로. 바뀐 행 수 1 이면 성공 (선점·취소가 겹쳐도 한쪽만)
  @Transactional
  @Modifying
  @Query("""
    update ScheduledAdminPush p set p.status = :to, p.updatedAt = :now
    where p.id = :id and p.status = :from
    """)
  int transition(@Param("id") String id, @Param("from") ScheduledAdminPushStatus from,
    @Param("to") ScheduledAdminPushStatus to, @Param("now") LocalDateTime now);
}
