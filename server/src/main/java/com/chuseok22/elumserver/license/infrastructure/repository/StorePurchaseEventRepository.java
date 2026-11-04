package com.chuseok22.elumserver.license.infrastructure.repository;

import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchaseEvent;
import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StorePurchaseEventRepository extends JpaRepository<StorePurchaseEvent, String> {

  boolean existsByStoreAndExternalEventId(SubscriptionSource store, String externalEventId);

  /// 관리자 회원 상세: 최신순 (limit 은 Pageable 로)
  List<StorePurchaseEvent> findByMemberIdOrderByOccurredAtDesc(String memberId, Pageable pageable);
}
