package com.chuseok22.elumserver.ai.infrastructure.repository;

import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AiCallLogRepository extends JpaRepository<AiCallLog, String> {

  Page<AiCallLog> findByCallType(AiCallType callType, Pageable pageable);

  Page<AiCallLog> findBySuccess(boolean success, Pageable pageable);

  Page<AiCallLog> findByCallTypeAndSuccess(AiCallType callType, boolean success, Pageable pageable);

  List<AiCallLog> findTop20ByMemberIdOrderByCreatedAtDesc(String memberId);

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
}
