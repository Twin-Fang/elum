package com.chuseok22.elumserver.credit.infrastructure.repository;

import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditRefundHold;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AiCreditRefundHoldRepository extends JpaRepository<AiCreditRefundHold, String> {

  Optional<AiCreditRefundHold> findByStoreAndTransactionId(SubscriptionSource store, String transactionId);
}
