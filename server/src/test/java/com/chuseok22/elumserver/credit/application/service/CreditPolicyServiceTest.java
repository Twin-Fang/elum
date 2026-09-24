package com.chuseok22.elumserver.credit.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

import com.chuseok22.elumserver.credit.core.CreditAction;
import com.chuseok22.elumserver.credit.core.CreditPeriod;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditPolicyRepository;
import com.chuseok22.elumserver.license.core.PlanType;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class CreditPolicyServiceTest {

  private static final ZoneId SEOUL = ZoneId.of("Asia/Seoul");
  /// 2026-09-23(수) 15:00 한국 시각.
  private static final Instant START = Instant.parse("2026-09-23T06:00:00Z");
  private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 23, 15, 0);

  @Mock
  private AiCreditPolicyRepository policyRepository;

  private final List<AiCreditPolicy> rows = new ArrayList<>();
  private final MutableClock clock = new MutableClock(START);
  private CreditPolicyService service;

  /// 캐시 만료를 보려고 시간을 앞으로 돌릴 수 있는 시계.
  private static final class MutableClock extends Clock {

    private Instant now;

    MutableClock(Instant now) {
      this.now = now;
    }

    void advance(Duration duration) {
      now = now.plus(duration);
    }

    @Override
    public ZoneId getZone() {
      return SEOUL;
    }

    @Override
    public Clock withZone(ZoneId zone) {
      return this;
    }

    @Override
    public Instant instant() {
      return now;
    }
  }

  @BeforeEach
  void setUp() {
    service = new CreditPolicyService(policyRepository, clock);
    // 실제 쿼리와 같은 규칙 — 시작 시각이 지난 것 중 가장 높은 버전.
    lenient().when(policyRepository.findFirstByEffectiveFromLessThanEqualOrderByVersionDesc(any()))
      .thenAnswer(inv -> {
        LocalDateTime at = inv.getArgument(0);
        return rows.stream()
          .filter(p -> !p.getEffectiveFrom().isAfter(at))
          .max(Comparator.comparingInt(AiCreditPolicy::getVersion));
      });
    // 실제 쿼리와 같은 규칙 — 이 적용 시점으로 (after, until] 에 시작한 것 중 가장 높은 버전.
    lenient().when(policyRepository
        .findFirstByGrantApplyAndEffectiveFromGreaterThanAndEffectiveFromLessThanEqualOrderByVersionDesc(any(), any(), any()))
      .thenAnswer(inv -> {
        String apply = inv.getArgument(0);
        LocalDateTime after = inv.getArgument(1);
        LocalDateTime until = inv.getArgument(2);
        return rows.stream()
          .filter(p -> apply.equals(p.getGrantApply()))
          .filter(p -> p.getEffectiveFrom().isAfter(after) && !p.getEffectiveFrom().isAfter(until))
          .max(Comparator.comparingInt(AiCreditPolicy::getVersion));
      });
    lenient().when(policyRepository.findFirstByOrderByVersionDesc())
      .thenAnswer(inv -> rows.stream().max(Comparator.comparingInt(AiCreditPolicy::getVersion)));
    lenient().when(policyRepository.save(any(AiCreditPolicy.class))).thenAnswer(inv -> {
      AiCreditPolicy policy = inv.getArgument(0);
      rows.add(policy);
      return policy;
    });
  }

  private AiCreditPolicy row(int version, boolean enabled, LocalDateTime effectiveFrom, String weekly, String costs) {
    AiCreditPolicy policy = AiCreditPolicy.disabledDefault();
    policy.setVersion(version);
    policy.setEnabled(enabled);
    policy.setEffectiveFrom(effectiveFrom);
    policy.setWeeklyGrantJson(weekly);
    policy.setActionCostsJson(costs);
    rows.add(policy);
    return policy;
  }

  /// 무료 지급량과 적용 시점만 다른 발행안.
  private static PolicyDraft grantDraft(int free, String grantApply) {
    return new PolicyDraft(true, Map.of(PlanType.FREE, free, PlanType.PRO, free),
      Map.of(CreditAction.ROUTINE_TEXT, 1, CreditAction.CARD_IMAGE, 1, CreditAction.IMAGE_REGENERATE, 1),
      15, grantApply, "지급량 " + free);
  }

  private static PolicyDraft draft(String reason) {
    return new PolicyDraft(true, Map.of(PlanType.FREE, 50, PlanType.PRO, 200),
      Map.of(CreditAction.ROUTINE_TEXT, 2, CreditAction.CARD_IMAGE, 1, CreditAction.IMAGE_REGENERATE, 1),
      20, AiCreditPolicy.GRANT_APPLY_NEXT_PERIOD, reason);
  }

  @Test
  @DisplayName("정책 행이 없으면 꺼진 기본 정책이다 — 크레딧 없이 기존 횟수 한도로 돈다")
  void noPolicy_disabledDefault() {
    AiCreditPolicy current = service.current();

    assertThat(current.isEnabled()).isFalse();
    assertThat(current.getVersion()).isZero();
  }

  @Test
  @DisplayName("시작 시각이 아직 안 된 버전은 쓰지 않는다")
  void futurePolicy_ignored() {
    row(1, true, NOW.minusDays(1), "{\"FREE\":100}", "{}");
    row(2, false, NOW.plusDays(1), "{\"FREE\":5}", "{}");

    assertThat(service.current().getVersion()).isEqualTo(1);
  }

  @Test
  @DisplayName("단가 키가 빠졌거나 JSON 이 깨졌으면 단가는 1, 지급량은 0 이다")
  void missingKeys_fallbacks() {
    AiCreditPolicy policy = row(1, true, NOW.minusDays(1), "{\"FREE\":100}", "{\"ROUTINE_TEXT\":3}");

    assertThat(policy.costOf(CreditAction.ROUTINE_TEXT)).isEqualTo(3);
    assertThat(policy.costOf(CreditAction.CARD_IMAGE)).isEqualTo(1);
    assertThat(policy.weeklyGrantFor(PlanType.FREE)).isEqualTo(100);
    assertThat(policy.weeklyGrantFor(PlanType.PRO)).isZero();

    policy.setActionCostsJson("{not json");
    assertThat(policy.costOf(CreditAction.ROUTINE_TEXT)).isEqualTo(1);
  }

  @Test
  @DisplayName("30초 안의 조회는 캐시를 쓰고, 지나면 다시 읽는다")
  void current_cachedFor30Seconds() {
    row(1, true, NOW.minusDays(1), "{}", "{}");

    service.current();
    clock.advance(Duration.ofSeconds(29));
    service.current();
    verify(policyRepository, times(1)).findFirstByEffectiveFromLessThanEqualOrderByVersionDesc(any());

    clock.advance(Duration.ofSeconds(2));
    service.current();
    verify(policyRepository, times(2)).findFirstByEffectiveFromLessThanEqualOrderByVersionDesc(any());
  }

  @Test
  @DisplayName("발행은 기존 행을 고치지 않고 version+1 새 행을 만든다 — 바로 current 에 보인다")
  void publish_appendsNextVersion() {
    AiCreditPolicy v1 = row(1, true, NOW.minusDays(1), "{\"FREE\":100,\"PRO\":100}", "{}");
    service.current();

    AiCreditPolicy published = service.publish(draft("지급량 조정"), "admin");

    assertThat(published.getVersion()).isEqualTo(2);
    assertThat(published.getEffectiveFrom()).isEqualTo(NOW);
    assertThat(published.weeklyGrantFor(PlanType.PRO)).isEqualTo(200);
    assertThat(published.costOf(CreditAction.ROUTINE_TEXT)).isEqualTo(2);
    assertThat(published.getReservationTtlMinutes()).isEqualTo(20);
    assertThat(published.getCreatedBy()).isEqualTo("admin");
    assertThat(published.getReason()).isEqualTo("지급량 조정");
    assertThat(v1.weeklyGrantFor(PlanType.PRO)).as("옛 버전은 그대로").isEqualTo(100);
    assertThat(service.current().getVersion()).as("발행하면 캐시를 비운다").isEqualTo(2);
  }

  @Test
  @DisplayName("사유 없는 발행은 거절한다")
  void publish_requiresReason() {
    assertThatThrownBy(() -> service.publish(draft("  "), "admin"))
      .isInstanceOf(IllegalArgumentException.class);
  }

  @Test
  @DisplayName("음수 지급량·단가나 1분 미만 TTL 은 거절한다")
  void publish_rejectsInvalidNumbers() {
    PolicyDraft negative = new PolicyDraft(true, Map.of(PlanType.FREE, -1), Map.of(), 15,
      AiCreditPolicy.GRANT_APPLY_NEXT_PERIOD, "사유");
    PolicyDraft zeroTtl = new PolicyDraft(true, Map.of(PlanType.FREE, 1), Map.of(), 0,
      AiCreditPolicy.GRANT_APPLY_NEXT_PERIOD, "사유");
    PolicyDraft badApply = new PolicyDraft(true, Map.of(PlanType.FREE, 1), Map.of(), 15, "LATER", "사유");

    assertThatThrownBy(() -> service.publish(negative, "admin")).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> service.publish(zeroTtl, "admin")).isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> service.publish(badApply, "admin")).isInstanceOf(IllegalArgumentException.class);
  }

  // --- 주간 지급에 쓰는 정책 (NEXT_PERIOD 가 이번 주로 새지 않는다) ---

  @Test
  @DisplayName("수요일에 NEXT_PERIOD 로 100→0 발행해도 목요일에 처음 온 회원은 이번 주 100, 다음 주부터 0 이다")
  void grantPolicyFor_nextPeriodPublishDoesNotLeakIntoThisWeek() {
    // 지난주부터 유효한 v1(100).
    row(1, true, NOW.minusWeeks(1), "{\"FREE\":100,\"PRO\":100}", "{}");
    service.publish(grantDraft(0, AiCreditPolicy.GRANT_APPLY_NEXT_PERIOD), "admin");

    clock.advance(Duration.ofDays(1)); // 목요일
    LocalDateTime thursday = NOW.plusDays(1);
    AiCreditPolicy thisWeek = service.grantPolicyFor(CreditPeriod.of(thursday));
    AiCreditPolicy nextWeek = service.grantPolicyFor(CreditPeriod.of(thursday.plusWeeks(1)));

    assertThat(thisWeek.getVersion()).isEqualTo(1);
    assertThat(thisWeek.weeklyGrantFor(PlanType.FREE)).isEqualTo(100);
    assertThat(nextWeek.getVersion()).isEqualTo(2);
    assertThat(nextWeek.weeklyGrantFor(PlanType.FREE)).isZero();
    assertThat(service.current().getVersion()).as("켜기·단가는 지금 정책을 쓴다").isEqualTo(2);
  }

  @Test
  @DisplayName("주 중간에 IMMEDIATE 로 발행하면 그 뒤 처음 온 회원도 새 지급량을 받는다")
  void grantPolicyFor_immediatePublishAppliesThisWeek() {
    row(1, true, NOW.minusWeeks(1), "{\"FREE\":100,\"PRO\":100}", "{}");
    service.publish(grantDraft(30, AiCreditPolicy.GRANT_APPLY_IMMEDIATE), "admin");

    clock.advance(Duration.ofDays(1));
    AiCreditPolicy thisWeek = service.grantPolicyFor(CreditPeriod.of(NOW.plusDays(1)));

    assertThat(thisWeek.getVersion()).isEqualTo(2);
    assertThat(thisWeek.weeklyGrantFor(PlanType.FREE)).isEqualTo(30);
  }

  @Test
  @DisplayName("이번 주에 IMMEDIATE 뒤 NEXT_PERIOD 를 발행하면 이번 주는 IMMEDIATE 지급량을 따른다")
  void grantPolicyFor_latestImmediateWinsOverLaterNextPeriod() {
    row(1, true, NOW.minusWeeks(1), "{\"FREE\":100,\"PRO\":100}", "{}");
    service.publish(grantDraft(30, AiCreditPolicy.GRANT_APPLY_IMMEDIATE), "admin");
    clock.advance(Duration.ofHours(1));
    service.publish(grantDraft(5, AiCreditPolicy.GRANT_APPLY_NEXT_PERIOD), "admin");

    AiCreditPolicy thisWeek = service.grantPolicyFor(CreditPeriod.of(NOW.plusHours(1)));

    assertThat(thisWeek.getVersion()).isEqualTo(2);
    assertThat(thisWeek.weeklyGrantFor(PlanType.FREE)).isEqualTo(30);
  }

  @Test
  @DisplayName("주 시작 때 버전이 없으면(V26 이 주 중간에 v1 을 넣었다) 지금 정책으로 준다")
  void grantPolicyFor_noVersionAtPeriodStart_usesCurrent() {
    row(1, true, NOW.minusHours(1), "{\"FREE\":100,\"PRO\":100}", "{}");

    AiCreditPolicy thisWeek = service.grantPolicyFor(CreditPeriod.of(NOW));

    assertThat(thisWeek.getVersion()).isEqualTo(1);
    assertThat(thisWeek.weeklyGrantFor(PlanType.FREE)).isEqualTo(100);
  }

  // --- 사유 길이 ---

  @Test
  @DisplayName("사유가 200자를 넘으면 폼 오류로 거절한다 — 500 으로 떨어지지 않는다")
  void publish_rejectsTooLongReason() {
    assertThatThrownBy(() -> service.publish(draft("가".repeat(201)), "admin"))
      .isInstanceOf(IllegalArgumentException.class)
      .hasMessageContaining("200");
    assertThat(rows).isEmpty();
  }

  @Test
  @DisplayName("정책 사유 컬럼(500)보다 긴 값은 저장 직전에 자른다")
  void policyReason_truncatedToColumnLength() {
    AiCreditPolicy policy = AiCreditPolicy.disabledDefault();

    policy.setReason("가".repeat(600));

    assertThat(policy.getReason()).hasSize(500);
  }
}
