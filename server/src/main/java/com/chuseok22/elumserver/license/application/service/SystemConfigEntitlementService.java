package com.chuseok22.elumserver.license.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.store.StoreLogValues;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.member.application.service.MemberSignupTimeService;
import com.chuseok22.elumserver.systemconfig.application.service.ConfigDateTime;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.Optional;
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
  private final MemberSignupTimeService memberSignupTimeService;
  private final ExistingMemberProGift existingMemberProGift;

  @Override
  @Transactional(readOnly = true)
  public PlanType planOf(String memberId) {
    if (memberId == null || memberId.isBlank()) {
      return PlanType.FREE;
    }
    try {
      Optional<Subscription> subscription = subscriptionRepository.findByMemberId(memberId);
      // 실제로 Pro 인 구독 행이 먼저 (선물·이벤트보다 우선)
      if (subscription.isPresent() && subscription.get().effectivePlan(LocalDateTime.now()) == PlanType.PRO) {
        return PlanType.PRO;
      }
      // 행 없음·가입 기본 Free 행 > 기존 가입자 선물
      if (subscription.map(Subscription::isUntouchedSignupFree).orElse(true)
        && existingMemberProGift.giftEndsAt(memberId).isPresent()) {
        return PlanType.PRO;
      }
      // 행이 없으면 Free (신규가입 PRO 이벤트 대상이면 Pro). 기존 회원을 옮기는 작업이 필요 없는 이유다.
      return subscription.isPresent() ? PlanType.FREE : planOfMemberWithoutSubscription(memberId);
    } catch (Exception e) {
      log.warn("구독 조회 실패 — Free로 계속 진행한다: memberId={}", memberId, e);
      return PlanType.FREE;
    }
  }

  // 구독 행 없는 회원: 신규가입 PRO 이벤트 대상이면 Pro, 아니면 Free (조회 시점 계산, DB 쓰기 없음)
  private PlanType planOfMemberWithoutSubscription(String memberId) {
    if (!systemConfigService.getBoolean(ConfigKey.SIGNUP_PRO_EVENT_ENABLED)) {
      return PlanType.FREE;
    }
    try {
      String startAtText = systemConfigService.getString(ConfigKey.SIGNUP_PRO_EVENT_START_AT);
      String endAtText = systemConfigService.getString(ConfigKey.SIGNUP_PRO_EVENT_END_AT);
      // 가입 기간이 비어 있으면 이벤트 꺼짐
      if (startAtText.isBlank() || endAtText.isBlank()) {
        return PlanType.FREE;
      }
      LocalDateTime signupWindowStart = ConfigDateTime.parse(startAtText);
      LocalDateTime signupWindowEnd = ConfigDateTime.parse(endAtText);
      int grantDays = systemConfigService.getInt(ConfigKey.SIGNUP_PRO_EVENT_GRANT_DAYS);
      return memberSignupTimeService.findSignupAt(memberId)
        .filter(signupAt -> !signupAt.isBefore(signupWindowStart) && !signupAt.isAfter(signupWindowEnd))
        // 가입 시점 + 유지 일수 이전까지만
        .filter(signupAt -> LocalDateTime.now().isBefore(signupAt.plusDays(grantDays)))
        .map(signupAt -> PlanType.PRO)
        .orElse(PlanType.FREE);
    } catch (Exception e) {
      log.warn("[signup pro event] evaluation failed, treating as FREE: memberId={}", memberId, e);
      return PlanType.FREE;
    }
  }

  @Override
  public boolean isAllowed(String memberId, Entitlement flag) {
    // 광고 항상 노출 회원은 플랜과 무관하게 광고 제거 불가
    if (flag == Entitlement.ADS_REMOVED && isAdsAlwaysShownMember(memberId)) {
      return false;
    }
    return isAllowed(planOf(memberId), flag);
  }

  @Override
  public void requireAllowed(String memberId, Entitlement flag) {
    // 거절 코드 먼저 (검문 대상이 아닌 권한이면 로그 전에 호출 코드 오류로 드러남)
    ErrorCode rejectionCode = flag.rejectionCode();
    if (!isAllowed(memberId, flag)) {
      log.info("[pro gate] rejected 403 : {} member={}", flag, StoreLogValues.mask(memberId));
      throw new CustomException(rejectionCode);
    }
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

  /// 앱에 내려줄 권한 한 벌: 플랜 1회 조회 > 플랜 기준 isAllowed·limitOf (광고 항상 노출 회원은 광고 제거 끔)
  @Override
  public EntitlementSnapshot snapshot(String memberId) {
    PlanType plan = planOf(memberId);
    return buildSnapshot(plan, !isAdsAlwaysShownMember(memberId) && isAllowed(plan, Entitlement.ADS_REMOVED));
  }

  /// 요금제 설정값 그대로 (광고 항상 노출 같은 회원별 예외 없음)
  @Override
  public EntitlementSnapshot planSnapshot(PlanType plan) {
    return buildSnapshot(plan, isAllowed(plan, Entitlement.ADS_REMOVED));
  }

  // 플랜 기준 권한 한 벌 (광고 제거만 부르는 쪽이 정함)
  private EntitlementSnapshot buildSnapshot(PlanType plan, boolean isAdsRemoved) {
    return new EntitlementSnapshot(
      plan,
      isAllowed(plan, Entitlement.AI_IMAGE_GENERATION),
      isAdsRemoved,
      limitOf(plan, Entitlement.ROUTINE_CREATE_PER_DAY),
      limitOf(plan, Entitlement.ROUTINE_CREATE_PER_WEEK),
      limitOf(plan, Entitlement.ROUTINE_MAX_COUNT),
      limitOf(plan, Entitlement.PROFILE_MAX_COUNT),
      limitOf(plan, Entitlement.HISTORY_RETENTION_DAYS),
      isAllowed(plan, Entitlement.CARD_EXPORT_WITHOUT_WATERMARK),
      isAllowed(plan, Entitlement.CARD_EXPORT_ALL_THEMES),
      isAllowed(plan, Entitlement.WEEKLY_REPORT),
      isAllowed(plan, Entitlement.ROUTINE_TRANSLATE),
      isAllowed(plan, Entitlement.ROUTINE_SCHEDULE),
      isAllowed(plan, Entitlement.GUARDIAN_VOICE),
      isAllowed(plan, Entitlement.ROUTINE_TEMPLATES),
      isAllowed(plan, Entitlement.ROUTINE_MEMORY),
      isAllowed(plan, Entitlement.IMAGE_REGENERATE_FREE),
      isAllowed(plan, Entitlement.ROUTINE_CREATE_FREE),
      isAllowed(plan, Entitlement.IMAGE_HIGH_QUALITY)
    );
  }

  // 광고 항상 노출 목록(쉼표 구분, 공백·빈 항목 무시)에 회원이 있는지
  private boolean isAdsAlwaysShownMember(String memberId) {
    if (memberId == null || memberId.isBlank()) {
      return false;
    }
    String memberIdsText = systemConfigService.getString(ConfigKey.ADS_ALWAYS_SHOWN_MEMBER_IDS);
    if (memberIdsText == null || memberIdsText.isBlank()) {
      return false;
    }
    return Arrays.stream(memberIdsText.split(","))
      .map(String::trim)
      .anyMatch(memberId.trim()::equals);
  }
}
