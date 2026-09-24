package com.chuseok22.elumserver.credit.infrastructure.repository;

import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository.AccountTotal;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/// 관리자 작업 탐색은 필터 조합이 많아 Specification 으로 조건을 붙인다 (#407).
public interface AiCreditJobRepository extends JpaRepository<AiCreditJob, String>, JpaSpecificationExecutor<AiCreditJob> {

  Optional<AiCreditJob> findByAccountIdAndRequestKey(String accountId, String requestKey);

  List<AiCreditJob> findByAccountIdAndStatus(String accountId, CreditJobStatus status);

  /**
   * 작업이 속한 계정 id 만 읽는다. 작업 행을 영속성 컨텍스트에 올리지 않는다.
   *
   * <p>정산·반환은 계정을 잠근 <b>뒤에</b> 작업을 읽어야 한다. 잠그기 전에 작업을 읽어 두면 그 사이 다른
   * 트랜잭션이 정산한 것을 못 보고(1차 캐시) 두 번 정산한다.
   */
  @Query("select j.accountId from AiCreditJob j where j.id = :id")
  Optional<String> findAccountIdById(@Param("id") String id);

  // --- 관리자 크레딧 화면 (#407) ---

  Page<AiCreditJob> findByAccountIdOrderByStartedAtDesc(String accountId, Pageable pageable);

  /// 이 상태 작업의 계정별 예약 합. 진행 중 예약(RESERVED)만 뜻이 있다.
  @Query("""
    select j.accountId as accountId, coalesce(sum(j.reserved), 0) as total
    from AiCreditJob j
    where j.status = :status
    group by j.accountId
    """)
  List<AccountTotal> sumReservedByAccount(@Param("status") CreditJobStatus status);

  /// 기간 [from, to) 에 끝난 작업의 계정별 초과 합. 초과가 있는 작업만 센다.
  @Query("""
    select j.accountId as accountId, coalesce(sum(j.overage), 0) as total, count(j) as jobCount
    from AiCreditJob j
    where j.overage > 0 and j.finishedAt >= :from and j.finishedAt < :to
    group by j.accountId
    """)
  List<AccountOverage> sumOverageByAccount(@Param("from") LocalDateTime from, @Param("to") LocalDateTime to);

  interface AccountOverage {

    String getAccountId();

    long getTotal();

    long getJobCount();
  }

  /// 반환·만료된 작업 수 — 원장 RELEASE 줄은 정산 때도 생기므로 작업 상태로 센다.
  long countByStatusInAndFinishedAtGreaterThanEqualAndFinishedAtLessThan(
    Collection<CreditJobStatus> statuses, LocalDateTime from, LocalDateTime to
  );

  /// 멈춘 예약 — 이 상태로 threshold 전에 시작한 작업.
  long countByStatusAndStartedAtBefore(CreditJobStatus status, LocalDateTime threshold);

  /**
   * 대조 불일치 — 청구(차감 또는 초과)가 있었는데 연결된 AI 호출 기록이 0건인 정산 작업 (#407).
   *
   * <p>호출 기록이 실패해도 크레딧은 정상으로 돈다(스펙 §3 실패 경로). 그 틈을 여기서 찾는다.
   */
  @Query("""
    select count(j) from AiCreditJob j
    where j.status = :status and (j.charged + j.overage) > 0
      and j.finishedAt >= :from and j.finishedAt < :to
      and not exists (select 1 from AiCallLog l where l.creditJobId = j.id)
    """)
  long countSettledWithoutCallLog(
    @Param("status") CreditJobStatus status, @Param("from") LocalDateTime from, @Param("to") LocalDateTime to
  );

  /// 기간 [from, to) 에 정산한 작업의 종류별 작업 수·연결 호출 수·비용. 호출이 없는 작업도 작업 수에 든다.
  @Query("""
    select j.kind as kind, count(distinct j.id) as jobCount, count(l.id) as callCount,
           coalesce(sum(l.estimatedCostUsd), 0) as totalCostUsd
    from AiCreditJob j
    left join AiCallLog l on l.creditJobId = j.id
    where j.status = :status and j.finishedAt >= :from and j.finishedAt < :to
    group by j.kind
    """)
  List<KindCost> sumCostByKind(
    @Param("status") CreditJobStatus status, @Param("from") LocalDateTime from, @Param("to") LocalDateTime to
  );

  interface KindCost {

    CreditJobKind getKind();

    long getJobCount();

    long getCallCount();

    double getTotalCostUsd();
  }
}
