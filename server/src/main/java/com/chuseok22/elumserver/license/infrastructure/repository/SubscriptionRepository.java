package com.chuseok22.elumserver.license.infrastructure.repository;

import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface SubscriptionRepository extends JpaRepository<Subscription, String> {

  Optional<Subscription> findByMemberId(String memberId);

  boolean existsByMemberId(String memberId);

  /// 탈퇴 시 정리한다. member를 외래키로 참조하므로 남겨 두면 계정이 지워지지 않는다.
  void deleteByMemberId(String memberId);
}
