package com.chuseok22.elumserver.license.application.service;

import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 한도를 시스템 설정에서 읽는 구현.
 *
 * <p>플랜이 Free·Pro 둘뿐인 동안은 이걸로 충분하다. 설정 값이라 관리자 화면에서 배포
 * 없이 바뀌고, 30초 캐시와 기본값 폴백을 그대로 얻는다.
 *
 * <p>구독 조회가 실패해도 예외를 밖으로 내지 않는다 — 우리 DB 문제로 사용자가 앱을 못
 * 쓰면 안 된다. 그런 경우 Free로 보고 로그를 남긴다. Free가 지금 모든 한도가
 * 무제한이라 실제로 막히는 일은 없지만, 숫자가 채워진 뒤에도 <b>막는 쪽이 아니라
 * 열어두는 쪽으로</b> 기울인다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SystemConfigEntitlementService implements EntitlementService {

  private final SubscriptionRepository subscriptionRepository;
  private final SystemConfigService systemConfigService;

  @Override
  @Transactional(readOnly = true)
  public PlanType planOf(String memberId) {
    if (memberId == null || memberId.isBlank()) {
      return PlanType.FREE;
    }
    try {
      return subscriptionRepository.findByMemberId(memberId)
        // 행이 없으면 Free다. 기존 회원을 옮기는 작업이 필요 없는 이유다.
        .map(subscription -> subscription.effectivePlan(LocalDateTime.now()))
        .orElse(PlanType.FREE);
    } catch (Exception e) {
      log.warn("구독 조회 실패 — Free로 계속 진행한다: memberId={}", memberId, e);
      return PlanType.FREE;
    }
  }

  @Override
  public boolean isAllowed(String memberId, Entitlement flag) {
    return isAllowed(planOf(memberId), flag);
  }

  @Override
  public int limitOf(String memberId, Entitlement limit) {
    return limitOf(planOf(memberId), limit);
  }

  @Override
  public boolean isWithinLimit(String memberId, Entitlement limit, long current) {
    return isWithinLimit(planOf(memberId), limit, current);
  }

  @Override
  public boolean isAllowed(PlanType plan, Entitlement flag) {
    return systemConfigService.getBoolean(flag.configKeyFor(plan));
  }

  @Override
  public int limitOf(PlanType plan, Entitlement limit) {
    return systemConfigService.getInt(limit.configKeyFor(plan));
  }

  @Override
  public boolean isWithinLimit(PlanType plan, Entitlement limit, long current) {
    int allowed = limitOf(plan, limit);
    if (allowed == Entitlement.UNLIMITED) {
      return true;
    }
    // 음수 한도는 -1(무제한) 말고는 뜻이 없다. 설정에 잘못된 값이 들어가도 사용자를
    // 막지 않고 통과시킨다.
    if (allowed < 0) {
      log.warn("알 수 없는 한도 값 — 통과시킨다: entitlement={}, value={}", limit, allowed);
      return true;
    }
    return current < allowed;
  }

  @Override
  public EntitlementSnapshot snapshot(String memberId) {
    PlanType plan = planOf(memberId);
    return new EntitlementSnapshot(
      plan,
      systemConfigService.getBoolean(Entitlement.AI_IMAGE_GENERATION.configKeyFor(plan)),
      systemConfigService.getBoolean(Entitlement.ADS_REMOVED.configKeyFor(plan)),
      systemConfigService.getInt(Entitlement.ROUTINE_CREATE_PER_DAY.configKeyFor(plan)),
      systemConfigService.getInt(Entitlement.ROUTINE_CREATE_PER_WEEK.configKeyFor(plan)),
      systemConfigService.getInt(Entitlement.ROUTINE_MAX_COUNT.configKeyFor(plan)),
      systemConfigService.getInt(Entitlement.PROFILE_MAX_COUNT.configKeyFor(plan)),
      systemConfigService.getInt(Entitlement.HISTORY_RETENTION_DAYS.configKeyFor(plan))
    );
  }
}
