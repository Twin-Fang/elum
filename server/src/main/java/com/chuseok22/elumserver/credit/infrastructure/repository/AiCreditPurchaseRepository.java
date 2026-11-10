package com.chuseok22.elumserver.credit.infrastructure.repository;

import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPurchase;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AiCreditPurchaseRepository extends JpaRepository<AiCreditPurchase, String> {

  Optional<AiCreditPurchase> findByStoreAndTransactionId(SubscriptionSource store, String transactionId);

  /// 환불 회수용: 같은 환불 알림 둘이 동시에 와도 한 줄로 선다
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select p from AiCreditPurchase p where p.store = :store and p.transactionId = :transactionId")
  Optional<AiCreditPurchase> findByStoreAndTransactionIdForUpdate(
    @Param("store") SubscriptionSource store, @Param("transactionId") String transactionId
  );

  /// 계정의 구매 기록, 최근 것부터 (관리자 회원 상세)
  List<AiCreditPurchase> findByAccountIdOrderByCreatedAtDesc(String accountId);

  /// 완전 삭제용: 구매 행(거래 id 멱등 키, 결제 기록)은 남기고 누구 것인지만 뗌 (member 외래키 없음)
  @Modifying(flushAutomatically = true)
  @Query("update AiCreditPurchase p set p.memberId = null where p.memberId = :memberId")
  int detachMember(@Param("memberId") String memberId);
}
