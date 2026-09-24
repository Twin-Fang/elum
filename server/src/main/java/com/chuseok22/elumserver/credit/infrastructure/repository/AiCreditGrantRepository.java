package com.chuseok22.elumserver.credit.infrastructure.repository;

import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository.AccountTotal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AiCreditGrantRepository extends JpaRepository<AiCreditGrant, String> {

  /// 이번 주 주간 지급. 없으면 아직 이번 주 첫 요청 전이다.
  Optional<AiCreditGrant> findByAccountIdAndPeriodKey(String accountId, String periodKey);

  /**
   * 아직 남은 양이 있는 묶음. 잔액 계산·차감·만료 처리가 모두 여기서 시작한다.
   *
   * <p>다 쓴 묶음은 빼고 읽는다 — 주마다 한 행씩 쌓여도 읽는 양이 늘지 않는다.
   */
  List<AiCreditGrant> findByAccountIdAndRemainingGreaterThan(String accountId, int remaining);

  /// 한 주기의 주간 지급 전부 (관리자 크레딧 — 주 단위 집계·IMMEDIATE 정책 조정, #407).
  List<AiCreditGrant> findByPeriodKey(String periodKey);

  /**
   * 한 주기의 이 출처 지급을 가진 계정 id 만 읽는다. 묶음 행을 영속성 컨텍스트에 올리지 않는다.
   *
   * <p>IMMEDIATE 정책 조정은 계정을 잠근 <b>뒤에</b> 묶음을 읽어야 한다 — 먼저 읽어 두면 그 사이 정산이 줄인
   * 남은 양을 못 보고(1차 캐시) 옛 값에 차이를 더한다.
   */
  @Query("select g.accountId from AiCreditGrant g where g.periodKey = :periodKey and g.source = :source")
  List<String> findAccountIdsByPeriodKeyAndSource(
    @Param("periodKey") String periodKey, @Param("source") CreditGrantSource source
  );

  /**
   * 기간 [from, to) 에 시작한 주간 외 지급(관리자 보너스 등)의 계정별 합 (#407).
   *
   * <p>주간 지급을 빼려고 source 를 인자로 받는다 — JPQL 에 enum 전체 경로를 적으면 오타를 잡기 어렵다.
   */
  @Query("""
    select g.accountId as accountId, coalesce(sum(g.amount), 0) as total
    from AiCreditGrant g
    where g.source <> :weekly and g.validFrom >= :from and g.validFrom < :to
    group by g.accountId
    """)
  List<AccountTotal> sumNonWeeklyGrantedByAccount(
    @Param("weekly") CreditGrantSource weekly, @Param("from") LocalDateTime from, @Param("to") LocalDateTime to
  );

  /// 지금 쓸 수 있는 주간 외 묶음의 계정별 남은 양 (#407).
  @Query("""
    select g.accountId as accountId, coalesce(sum(g.remaining), 0) as total
    from AiCreditGrant g
    where g.source <> :weekly and g.remaining > 0
      and g.validFrom <= :now and (g.expiresAt is null or g.expiresAt > :now)
    group by g.accountId
    """)
  List<AccountTotal> sumValidNonWeeklyRemainingByAccount(
    @Param("weekly") CreditGrantSource weekly, @Param("now") LocalDateTime now
  );
}
