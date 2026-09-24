package com.chuseok22.elumserver.credit.infrastructure.repository;

import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AiCreditPolicyRepository extends JpaRepository<AiCreditPolicy, String> {

  /// 지금 유효한 정책 = 시작 시각이 지난 것 중 가장 높은 버전.
  Optional<AiCreditPolicy> findFirstByEffectiveFromLessThanEqualOrderByVersionDesc(LocalDateTime now);

  /**
   * 기간 (after, until] 에 시작한 이 적용 시점의 버전 중 가장 높은 것.
   *
   * <p>주 중간에 IMMEDIATE 로 발행한 버전을 찾는다 — 그 주의 주간 지급량을 바꾸는 유일한 경로다.
   */
  Optional<AiCreditPolicy> findFirstByGrantApplyAndEffectiveFromGreaterThanAndEffectiveFromLessThanEqualOrderByVersionDesc(
    String grantApply, LocalDateTime after, LocalDateTime until
  );

  /// 가장 최근 발행본(아직 시작 전이어도). 새 버전 번호를 매길 때 쓴다.
  Optional<AiCreditPolicy> findFirstByOrderByVersionDesc();

  List<AiCreditPolicy> findAllByOrderByVersionDesc();
}
