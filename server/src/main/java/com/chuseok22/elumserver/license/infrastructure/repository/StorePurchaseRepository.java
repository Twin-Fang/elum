package com.chuseok22.elumserver.license.infrastructure.repository;

import com.chuseok22.elumserver.license.core.StorePurchaseState;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import java.util.Collection;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchase;
import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface StorePurchaseRepository extends JpaRepository<StorePurchase, String> {

  /// 같은 구매를 검증 요청·알림이 동시에 바꾸지 않게 행 잠금 (같은 트랜잭션 안에서만)
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select p from StorePurchase p where p.store = :store and p.purchaseKey = :purchaseKey")
  Optional<StorePurchase> findForUpdate(@Param("store") SubscriptionSource store, @Param("purchaseKey") String purchaseKey);

  List<StorePurchase> findByMemberId(String memberId);

  /// 환불 재확인 대상: 스토어별 Pro 를 주는 상태(ACTIVE·유예)이고 회수 전인 구매
  List<StorePurchase> findByStoreAndStateInAndRevokedAtIsNull(SubscriptionSource store, Collection<StorePurchaseState> states);
}
