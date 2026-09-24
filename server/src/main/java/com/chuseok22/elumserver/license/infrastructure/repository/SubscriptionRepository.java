package com.chuseok22.elumserver.license.infrastructure.repository;

import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionStatus;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SubscriptionRepository extends JpaRepository<Subscription, String> {

  Optional<Subscription> findByMemberId(String memberId);

  boolean existsByMemberId(String memberId);

  /// 탈퇴 시 정리한다. member를 외래키로 참조하므로 남겨 두면 계정이 지워지지 않는다.
  void deleteByMemberId(String memberId);

  /**
   * 지금 이 플랜으로 동작하는 회원 id. {@code Subscription.effectivePlan} 과 같은 조건이다(ACTIVE · 만료 전).
   *
   * <p>관리자 크레딧 화면이 플랜별 주간 지급 총량을 셀 때 쓴다 — 회원마다 planOf 를 부르지 않으려고 (#407).
   */
  @Query("""
    select s.member.id from Subscription s
    where s.plan = :plan and s.status = :status
      and (s.expiresAt is null or s.expiresAt >= :now)
    """)
  List<String> findMemberIdsWithEffectivePlan(
    @Param("plan") PlanType plan, @Param("status") SubscriptionStatus status, @Param("now") LocalDateTime now
  );
}
