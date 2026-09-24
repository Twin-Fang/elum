package com.chuseok22.elumserver.credit.infrastructure.repository;

import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import java.time.LocalDateTime;
import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/// 추가 전용 원장. save 만 쓰고 고치지 않는다. balance_after 는 호출자가 계산해 넣는다.
public interface AiCreditLedgerRepository extends JpaRepository<AiCreditLedger, String> {

  /// 기간 [from, to) 안 이 종류 줄의 delta 합. 이번 주 사용량 = −(CONSUME 합). 0건이면 0.
  @Query("""
    select coalesce(sum(l.delta), 0) from AiCreditLedger l
    where l.accountId = :accountId and l.type = :type
      and l.createdAt >= :from and l.createdAt < :to
    """)
  long sumDelta(
    @Param("accountId") String accountId, @Param("type") CreditLedgerType type,
    @Param("from") LocalDateTime from, @Param("to") LocalDateTime to
  );

  // --- 관리자 크레딧 화면 (#407) ---

  Page<AiCreditLedger> findByAccountIdOrderByCreatedAtDesc(String accountId, Pageable pageable);

  Page<AiCreditLedger> findByAccountIdAndTypeOrderByCreatedAtDesc(
    String accountId, CreditLedgerType type, Pageable pageable
  );

  /// 기간 [from, to) 안 이 종류 줄의 계정별 delta 합. 사용량은 CONSUME 합의 부호를 뒤집는다.
  @Query("""
    select l.accountId as accountId, coalesce(sum(l.delta), 0) as total
    from AiCreditLedger l
    where l.type = :type and l.createdAt >= :from and l.createdAt < :to
    group by l.accountId
    """)
  List<AccountTotal> sumDeltaByAccount(
    @Param("type") CreditLedgerType type, @Param("from") LocalDateTime from, @Param("to") LocalDateTime to
  );

  /// 한 주기의 주간 지급에서 만료된 양(EXPIRE 는 음수)의 계정별 합. 지난 주 "주 말에 남은 양"을 되살린다.
  @Query("""
    select l.accountId as accountId, coalesce(sum(l.delta), 0) as total
    from AiCreditLedger l
    where l.type = :type
      and l.grantId in (select g.id from AiCreditGrant g where g.periodKey = :periodKey)
    group by l.accountId
    """)
  List<AccountTotal> sumDeltaOfPeriodGrantsByAccount(
    @Param("type") CreditLedgerType type, @Param("periodKey") String periodKey
  );

  /// 이 종류 줄의 계정별 마지막 시각. 마지막 사용 = CONSUME 의 최댓값.
  @Query("""
    select l.accountId as accountId, max(l.createdAt) as lastAt
    from AiCreditLedger l
    where l.type = :type
    group by l.accountId
    """)
  List<AccountLastAt> lastAtByAccount(@Param("type") CreditLedgerType type);

  /// 계정별 합계 한 줄.
  interface AccountTotal {

    String getAccountId();

    long getTotal();
  }

  interface AccountLastAt {

    String getAccountId();

    LocalDateTime getLastAt();
  }
}
