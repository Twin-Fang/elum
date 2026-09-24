package com.chuseok22.elumserver.ai.infrastructure.repository;

import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import java.time.LocalDateTime;
import java.util.Collection;
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
   * 특정 기간에 이 회원이 낸 호출 건수. 요금제 한도 계산에 쓴다.
   *
   * <p>일과 표를 세지 않는 이유는 <b>지우면 행이 사라져 우회되기 때문</b>이다. 만들고
   * 지우고 다시 만들면 보유 개수는 그대로인데 AI 비용은 그때마다 나간다. 이 표는
   * 지워지지 않으므로 실제로 쓴 것을 센다.
   *
   * <p>성공한 호출만 센다 — 실패는 결과물이 없으므로 한도를 깎지 않는다.
   *
   * <p>유형을 목록으로 받는다. 같은 일을 하는 호출이 제공자마다 다른 유형으로 남기 때문이다 —
   * 하나만 받으면 제공자를 바꾸는 순간 사용량이 끊긴다 (#367).
   *
   * <p>{@code idx_ai_call_log_member_created}(member_id, created_at)를 그대로 탄다.
   */
  long countByMemberIdAndCallTypeInAndSuccessIsTrueAndCreatedAtGreaterThanEqual(
    String memberId, Collection<AiCallType> callTypes, LocalDateTime from
  );

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

  /// 기간 [from, to) 의 추정 비용 합. 0건이면 0 (#407 관리자 크레딧 — 크레딧당 원가의 분자).
  @Query("""
    select coalesce(sum(l.estimatedCostUsd), 0) from AiCallLog l
    where l.createdAt >= :from and l.createdAt < :to
    """)
  double sumCostBetween(@Param("from") LocalDateTime from, @Param("to") LocalDateTime to);

  /// 기간 [from, to) 의 모델별 호출 수·비용 (#407). 모델이 비어 있는 호출도 한 줄로 모인다.
  @Query("""
    select l.model as model, count(l) as callCount, coalesce(sum(l.estimatedCostUsd), 0) as totalCostUsd
    from AiCallLog l
    where l.createdAt >= :from and l.createdAt < :to
    group by l.model
    """)
  List<ModelCost> sumCostByModelBetween(@Param("from") LocalDateTime from, @Param("to") LocalDateTime to);

  interface ModelCost {

    String getModel();

    long getCallCount();

    double getTotalCostUsd();
  }

  /// 크레딧 작업별로 연결된 호출 수·비용 (#407). 작업 목록 한 페이지를 한 번에 대조한다.
  @Query("""
    select l.creditJobId as creditJobId, count(l) as callCount, coalesce(sum(l.estimatedCostUsd), 0) as totalCostUsd
    from AiCallLog l
    where l.creditJobId in :jobIds
    group by l.creditJobId
    """)
  List<CreditJobCost> sumCostByCreditJobIds(@Param("jobIds") Collection<String> jobIds);

  interface CreditJobCost {

    String getCreditJobId();

    long getCallCount();

    double getTotalCostUsd();
  }

  interface MemberAiUsage {

    String getMemberId();

    long getCallCount();

    long getTotalTokens();

    double getTotalCostUsd();
  }
}
