package com.chuseok22.elumserver.license.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionHistoryAction;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.core.SubscriptionStatus;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import com.chuseok22.elumserver.license.infrastructure.entity.SubscriptionHistory;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionHistoryRepository;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 구독 행을 만들고 바꾼다. 권한을 <b>묻는</b> 것은 {@link EntitlementService}가 한다.
 *
 * <p>가입 시 Free 생성, 관리자 Pro 발급·회수, 스토어 결제 반영({@link #syncStoreEntitlement}, #1071).
 * 스토어 결제는 {@code source}(APPLE_IAP·GOOGLE_IAP)와 {@code externalRef}(store_purchase.id)를 채운다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SubscriptionService {

  /// 회수 사유를 비웠을 때 구독 메모와 이력에 남기는 문구
  public static final String DEFAULT_REVOKE_REASON = "관리자 회수";
  /// 변경자를 알 수 없을 때 이력에 남기는 값 (이력 자체는 빠뜨리지 않음)
  public static final String UNKNOWN_ACTOR = "unknown";
  /// 스토어 결제가 만든 구독 출처 2개
  private static final Set<SubscriptionSource> STORE_SOURCES = Set.of(SubscriptionSource.APPLE_IAP, SubscriptionSource.GOOGLE_IAP);
  /// 스토어 구독이 끝나 Free 로 돌릴 때 메모·이력 사유
  static final String STORE_END_REASON = "스토어 구독 종료";

  private final SubscriptionRepository subscriptionRepository;
  private final SubscriptionHistoryRepository subscriptionHistoryRepository;
  private final MemberRepository memberRepository;

  /**
   * 가입한 계정에 Free 구독을 만들어 둔다.
   *
   * <p>행이 없어도 Free로 보긴 하지만, 그래도 만들어 두는 이유는 관리자 화면에서 모든
   * 계정의 구독이 같은 모양으로 보이고 "언제부터 Free였는지"가 남기 때문이다.
   *
   * <p><b>예외를 삼키지 않는다.</b> 가입과 같은 트랜잭션이라 여기서 잡아도 커밋 시점에
   * 롤백된다 — 삼키면 "가입은 계속된다"고 믿게 만들 뿐 실제로는 안 된다. 작동하지 않는
   * 안전장치를 두느니 실패를 드러낸다.
   *
   * <p>그래도 최악의 경우가 안전한 이유는 따로 있다. <b>구독 행이 없어도 Free로
   * 동작</b>하므로, 어떤 이유로든 행이 안 만들어진 계정도 권한 판정에서 문제가 없다.
   */
  @Transactional
  public void createFreeIfAbsent(Member member) {
    if (member == null || member.getId() == null) {
      return;
    }
    if (subscriptionRepository.existsByMemberId(member.getId())) {
      return;
    }
    Subscription subscription = new Subscription();
    subscription.setMember(member);
    subscription.setPlan(PlanType.FREE);
    subscription.setStatus(SubscriptionStatus.ACTIVE);
    subscription.setSource(SubscriptionSource.SIGNUP);
    subscription.setStartedAt(LocalDateTime.now());
    subscriptionRepository.save(subscription);
  }

  @Transactional(readOnly = true)
  public Optional<Subscription> find(String memberId) {
    return subscriptionRepository.findByMemberId(memberId);
  }

  /**
   * 관리자가 Pro를 켠다: 사유 검증 > 구독 갱신 > 이력 기록 (같은 트랜잭션)
   *
   * @param days   null 이거나 0 이하면 무기한
   * @param reason 왜 켰는지. 나중에 "이 계정은 왜 Pro지"에 답하려면 있어야 하므로 필수다
   * @param actor  변경한 관리자 로그인 이름
   */
  @Transactional
  public Subscription grantPro(String memberId, Integer days, String reason, String actor) {
    if (reason == null || reason.isBlank()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    Member member = memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));

    LocalDateTime now = LocalDateTime.now();
    boolean isLimitedPeriod = days != null && days > 0;
    LocalDateTime expiresAt = isLimitedPeriod ? now.plusDays(days) : null;

    Subscription subscription = subscriptionRepository.findByMemberId(memberId)
      .orElseGet(() -> {
        Subscription created = new Subscription();
        created.setMember(member);
        return created;
      });
    PlanType beforePlan = subscription.effectivePlan(now);
    LocalDateTime beforeExpiresAt = subscription.getExpiresAt();

    subscription.setPlan(PlanType.PRO);
    subscription.setStatus(SubscriptionStatus.ACTIVE);
    subscription.setSource(SubscriptionSource.MANUAL);
    subscription.setStartedAt(now);
    subscription.setExpiresAt(expiresAt);
    subscription.setMemo(reason.trim());
    Subscription saved = subscriptionRepository.save(subscription);

    recordHistory(memberId, SubscriptionHistoryAction.GRANT, beforePlan, PlanType.PRO,
      isLimitedPeriod ? days : null, beforeExpiresAt, expiresAt, reason.trim(), actor, now);
    log.info("관리자가 Pro를 발급했습니다: memberId={}, expiresAt={}, reason={}, actor={}",
      memberId, expiresAt, reason, actor);
    return saved;
  }

  /**
   * Pro를 거둔다: 구독을 Free로 되돌림 > 이력 기록 (같은 트랜잭션)
   * 행을 지우지 않는다 — 지우면 언제 무엇을 했는지가 사라진다. 구독 행이 없으면 바뀔 상태가 없어 이력도 없다
   */
  @Transactional
  public void revokePro(String memberId, String reason, String actor) {
    subscriptionRepository.findByMemberId(memberId).ifPresent(subscription -> {
      LocalDateTime now = LocalDateTime.now();
      PlanType beforePlan = subscription.effectivePlan(now);
      LocalDateTime beforeExpiresAt = subscription.getExpiresAt();
      String reasonOrDefault = reason == null || reason.isBlank() ? DEFAULT_REVOKE_REASON : reason.trim();

      subscription.setPlan(PlanType.FREE);
      subscription.setStatus(SubscriptionStatus.ACTIVE);
      subscription.setSource(SubscriptionSource.MANUAL);
      subscription.setExpiresAt(null);
      subscription.setExternalRef(null);
      subscription.setMemo(reasonOrDefault);
      subscriptionRepository.save(subscription);

      recordHistory(memberId, SubscriptionHistoryAction.REVOKE, beforePlan, PlanType.FREE,
        null, beforeExpiresAt, null, reasonOrDefault, actor, now);
      log.info("관리자가 Pro를 회수했습니다: memberId={}, actor={}", memberId, actor);
    });
  }

  /**
   * 스토어 결제 반영: 회원 확인 > 구독 행 잠금 > Pro 반영 또는 스토어발 Pro 종료 > 이력 (같은 트랜잭션)
   * 관리자·프로모션 Pro 가 스토어보다 오래가면 덮지 않음. 탈퇴 회원은 건드리지 않음. 바뀐 게 없으면 이력 없음
   *
   * @param entitlement Pro 를 주는 스토어 구매, 없으면 null (스토어발 Pro 를 Free 로)
   * @return 구독 행이 바뀌었는가
   */
  @Transactional
  public boolean syncStoreEntitlement(String memberId, StoreEntitlement entitlement, LocalDateTime now) {
    Member member = memberRepository.findById(memberId).orElse(null);
    if (member == null || member.getStatus() == MemberStatus.WITHDRAWN) {
      return false;
    }
    Subscription subscription = subscriptionRepository.findByMemberIdForUpdate(memberId).orElseGet(() -> {
      Subscription created = new Subscription();
      created.setMember(member);
      created.setStartedAt(now);
      return created;
    });
    return entitlement == null
      ? endStoreEntitlement(memberId, subscription, now)
      : applyStoreEntitlement(memberId, subscription, entitlement, now);
  }

  /// 스토어 반영 이력의 변경자: app-store, google-play
  public static String storeActorOf(SubscriptionSource store) {
    return store == SubscriptionSource.APPLE_IAP ? "app-store" : "google-play";
  }

  /// 탈퇴하지 않은 회원인가 (스토어 구매 주인 판정, 없는 회원은 false)
  @Transactional(readOnly = true)
  public boolean isActiveMember(String memberId) {
    if (memberId == null || memberId.isBlank()) {
      return false;
    }
    return memberRepository.findById(memberId).map(member -> member.getStatus() != MemberStatus.WITHDRAWN).orElse(false);
  }

  private boolean applyStoreEntitlement(
    String memberId, Subscription subscription, StoreEntitlement entitlement, LocalDateTime now
  ) {
    PlanType beforePlan = subscription.effectivePlan(now);
    LocalDateTime beforeExpiresAt = subscription.getExpiresAt();
    // 관리자·프로모션 Pro 가 스토어 구독보다 오래가면 그대로 (스토어가 끝날 때 함께 사라지지 않게)
    boolean isStoreOwned = STORE_SOURCES.contains(subscription.getSource());
    boolean isLongerNonStorePro = !isStoreOwned && beforePlan == PlanType.PRO
      && (beforeExpiresAt == null || !beforeExpiresAt.isBefore(entitlement.entitledUntil()));
    if (isLongerNonStorePro) {
      return false;
    }
    boolean isUnchanged = isStoreOwned && beforePlan == PlanType.PRO
      && subscription.getSource() == entitlement.store()
      && entitlement.purchaseId().equals(subscription.getExternalRef())
      && entitlement.entitledUntil().equals(beforeExpiresAt);
    if (isUnchanged) {
      return false;
    }
    if (beforePlan != PlanType.PRO || !isStoreOwned) {
      subscription.setStartedAt(now);
    }
    String reason = entitlement.store().getLabel() + " (" + entitlement.productId() + ")";
    subscription.setPlan(PlanType.PRO);
    subscription.setStatus(SubscriptionStatus.ACTIVE);
    subscription.setSource(entitlement.store());
    subscription.setExpiresAt(entitlement.entitledUntil());
    subscription.setExternalRef(entitlement.purchaseId());
    subscription.setMemo(reason);
    subscriptionRepository.save(subscription);
    recordHistory(memberId, SubscriptionHistoryAction.STORE_SYNC, beforePlan, PlanType.PRO,
      null, beforeExpiresAt, entitlement.entitledUntil(), reason, storeActorOf(entitlement.store()), now);
    return true;
  }

  // 스토어가 만든 Pro 만 Free 로 (관리자·가입 구독은 그대로)
  private boolean endStoreEntitlement(String memberId, Subscription subscription, LocalDateTime now) {
    boolean isStoreOwnedPro = STORE_SOURCES.contains(subscription.getSource()) && subscription.getPlan() == PlanType.PRO;
    if (!isStoreOwnedPro) {
      return false;
    }
    PlanType beforePlan = subscription.effectivePlan(now);
    LocalDateTime beforeExpiresAt = subscription.getExpiresAt();
    String actor = storeActorOf(subscription.getSource());
    subscription.setPlan(PlanType.FREE);
    subscription.setStatus(SubscriptionStatus.ACTIVE);
    subscription.setExpiresAt(null);
    subscription.setExternalRef(null);
    subscription.setMemo(STORE_END_REASON);
    subscriptionRepository.save(subscription);
    recordHistory(memberId, SubscriptionHistoryAction.STORE_END, beforePlan, PlanType.FREE,
      null, beforeExpiresAt, null, STORE_END_REASON, actor, now);
    return true;
  }

  /// 탈퇴 계정을 완전히 지울 때 요금제 이력도 함께 지운다
  @Transactional
  public void deleteHistoryOf(String memberId) {
    subscriptionHistoryRepository.deleteByMemberId(memberId);
  }

  /// 지금 유효한 Pro 회원수 (ACTIVE · 만료 전 PRO, 탈퇴 회원 제외)
  @Transactional(readOnly = true)
  public long countEffectivePro(LocalDateTime now) {
    return subscriptionRepository.countEffectiveMembersByPlan(PlanType.PRO, SubscriptionStatus.ACTIVE, now);
  }

  /// 목록 페이지에 실린 회원들의 구독을 한 번에 (회원 id > 구독)
  @Transactional(readOnly = true)
  public Map<String, Subscription> findAllByMemberIds(Collection<String> memberIds) {
    if (memberIds.isEmpty()) {
      return Map.of();
    }
    return subscriptionRepository.findByMemberIdIn(memberIds).stream()
      .collect(Collectors.toMap(subscription -> subscription.getMember().getId(), Function.identity(), (first, later) -> first));
  }

  private void recordHistory(
    String memberId, SubscriptionHistoryAction action, PlanType beforePlan, PlanType afterPlan,
    Integer durationDays, LocalDateTime beforeExpiresAt, LocalDateTime afterExpiresAt,
    String reason, String actor, LocalDateTime changedAt
  ) {
    SubscriptionHistory history = new SubscriptionHistory();
    history.setMemberId(memberId);
    history.setAction(action);
    history.setBeforePlan(beforePlan);
    history.setAfterPlan(afterPlan);
    history.setDurationDays(durationDays);
    history.setBeforeExpiresAt(beforeExpiresAt);
    history.setAfterExpiresAt(afterExpiresAt);
    history.setReason(reason);
    history.setChangedBy(actor == null || actor.isBlank() ? UNKNOWN_ACTOR : actor.trim());
    history.setChangedAt(changedAt);
    subscriptionHistoryRepository.save(history);
  }
}
