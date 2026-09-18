package com.chuseok22.elumserver.license.infrastructure.repository;

import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SubscriptionRepository extends JpaRepository<Subscription, String> {

  Optional<Subscription> findByMemberId(String memberId);

  boolean existsByMemberId(String memberId);
}
