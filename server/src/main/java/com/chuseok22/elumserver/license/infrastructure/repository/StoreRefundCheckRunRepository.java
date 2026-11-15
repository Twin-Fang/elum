package com.chuseok22.elumserver.license.infrastructure.repository;

import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StoreRefundCheckRun;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface StoreRefundCheckRunRepository extends JpaRepository<StoreRefundCheckRun, String> {

  /// 관리자 화면 최근 실행 (스토어 둘 섞어 최신순)
  List<StoreRefundCheckRun> findAllByOrderByStartedAtDesc(Pageable pageable);

  Optional<StoreRefundCheckRun> findFirstByStoreOrderByStartedAtDesc(SubscriptionSource store);

  /// since 이후 끝까지 성공한 실행이 있는가
  boolean existsByStoreAndFailureReasonIsNullAndStartedAtAfter(SubscriptionSource store, LocalDateTime since);
}
