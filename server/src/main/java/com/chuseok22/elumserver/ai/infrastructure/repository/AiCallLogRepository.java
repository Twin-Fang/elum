package com.chuseok22.elumserver.ai.infrastructure.repository;

import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AiCallLogRepository extends JpaRepository<AiCallLog, String> {

  Page<AiCallLog> findByCallType(AiCallType callType, Pageable pageable);

  Page<AiCallLog> findBySuccess(boolean success, Pageable pageable);

  Page<AiCallLog> findByCallTypeAndSuccess(AiCallType callType, boolean success, Pageable pageable);

  List<AiCallLog> findTop20ByMemberIdOrderByCreatedAtDesc(String memberId);

  /**
   * 탈퇴한 회원의 식별자만 떼어낸다. 행 자체는 남긴다.
   *
   * <p>이 표는 운영 지표(호출량·비용)를 보기 위한 것이라 행을 지우면 과거 집계가 줄어든다.
   * 반대로 식별자를 그대로 두면 계정이 사라진 뒤에도 누가 썼는지가 남는다. 둘 다 피하려고
   * 식별자만 비운다.
   *
   * <p>member를 외래키로 참조하지 않아 DB가 대신 처리해 주지 않는다 — 여기서 직접 해야 한다.
   */
  @Modifying(clearAutomatically = true, flushAutomatically = true)
  @Query("update AiCallLog l set l.memberId = null where l.memberId = :memberId")
  int detachMember(@Param("memberId") String memberId);

  // 기간 요약 통계. 로그가 0건이어도 null 대신 0이 나오도록 coalesce로 감싼다.
  @Query("""
    select count(l) as totalCount,
           coalesce(sum(case when l.success = true then 1 else 0 end), 0) as successCount,
           coalesce(avg(l.latencyMs), 0) as avgLatencyMs,
           coalesce(sum(l.totalTokens), 0) as totalTokens,
           coalesce(sum(l.estimatedCostUsd), 0) as totalCostUsd
    from AiCallLog l
    where l.createdAt >= :from
    """)
  AiCallStats statsSince(@Param("from") LocalDateTime from);

  interface AiCallStats {

    long getTotalCount();

    long getSuccessCount();

    double getAvgLatencyMs();

    long getTotalTokens();

    double getTotalCostUsd();
  }

  // 회원 목록 화면용 회원별 사용량 집계 — 회원 수만큼 쿼리가 나가지 않도록 in + group by 한 번에.
  @Query("""
    select l.memberId as memberId,
           count(l) as callCount,
           coalesce(sum(l.totalTokens), 0) as totalTokens,
           coalesce(sum(l.estimatedCostUsd), 0) as totalCostUsd
    from AiCallLog l
    where l.memberId in :memberIds
    group by l.memberId
    """)
  List<MemberAiUsage> aggregateUsageByMemberIds(@Param("memberIds") List<String> memberIds);

  interface MemberAiUsage {

    String getMemberId();

    long getCallCount();

    long getTotalTokens();

    double getTotalCostUsd();
  }
}
