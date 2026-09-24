package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.request.CreditAdjustType;
import com.chuseok22.elumserver.admin.application.dto.response.CreditAdjustPreview;
import com.chuseok22.elumserver.admin.application.dto.response.CreditPolicyPreview;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.application.service.CreditPolicyService;
import com.chuseok22.elumserver.credit.application.service.CreditTestStore;
import com.chuseok22.elumserver.credit.application.service.PolicyDraft;
import com.chuseok22.elumserver.credit.core.CreditAccountStatus;
import com.chuseok22.elumserver.credit.core.CreditAction;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.core.CreditPeriod;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditPolicyRepository;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class AdminCreditServiceTest {

  private static final String MEMBER_ID = "m1";
  private static final String ACCOUNT_ID = "acc1";
  private static final String ADMIN = "admin1";
  /// 2026-09-23(수) 15:00 한국 시각 — 2026-W39.
  private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-09-23T06:00:00Z"), ZoneId.of("Asia/Seoul"));
  private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 23, 15, 0);
  private static final CreditPeriod PERIOD = CreditPeriod.of(NOW);

  @Mock
  private AiCreditAccountRepository accountRepository;
  @Mock
  private AiCreditGrantRepository grantRepository;
  @Mock
  private AiCreditJobRepository jobRepository;
  @Mock
  private AiCreditLedgerRepository ledgerRepository;
  @Mock
  private AiCreditPolicyRepository policyRepository;
  @Mock
  private AiCallLogRepository aiCallLogRepository;
  @Mock
  private SubscriptionRepository subscriptionRepository;
  @Mock
  private MemberRepository memberRepository;
  @Mock
  private SystemConfigService systemConfigService;

  private final CreditTestStore store = new CreditTestStore();
  private CreditAccountService accountService;
  private AdminCreditService service;
  private AiCreditAccount account;
  private AiCreditPolicy policy;

  @BeforeEach
  void setUp() {
    store.wire(accountRepository, grantRepository, jobRepository, ledgerRepository);
    accountService = new CreditAccountService(accountRepository, grantRepository, jobRepository, ledgerRepository,
      org.mockito.Mockito.mock(jakarta.persistence.EntityManager.class));

    policy = AiCreditPolicy.disabledDefault();
    policy.setVersion(1);
    policy.setEnabled(true);
    policy.setWeeklyGrantJson("{\"FREE\":100,\"PRO\":100}");
    policy.setActionCostsJson("{\"ROUTINE_TEXT\":1,\"CARD_IMAGE\":1,\"IMAGE_REGENERATE\":1}");
    lenient().when(policyRepository.findFirstByEffectiveFromLessThanEqualOrderByVersionDesc(any()))
      .thenReturn(Optional.of(policy));
    lenient().when(policyRepository.findFirstByOrderByVersionDesc()).thenReturn(Optional.of(policy));
    lenient().when(policyRepository.save(any(AiCreditPolicy.class))).thenAnswer(inv -> inv.getArgument(0));
    // 정책 서비스는 진짜를 쓴다 — 발행이 새 버전을 만들고 지급량 JSON 을 쓰는 것까지 흐름에 넣는다.
    CreditPolicyService policyService = new CreditPolicyService(policyRepository);

    lenient().when(memberRepository.existsById(anyString())).thenReturn(true);
    lenient().when(subscriptionRepository.findMemberIdsWithEffectivePlan(any(), any(), any())).thenReturn(List.of());

    service = new AdminCreditService(policyService, accountService, accountRepository, grantRepository,
      jobRepository, ledgerRepository, aiCallLogRepository, subscriptionRepository, memberRepository,
      systemConfigService, CLOCK);
    account = store.account(ACCOUNT_ID, MEMBER_ID);
  }

  private int available() {
    return accountService.balance(account, NOW).available();
  }

  private static void assertFormError(Runnable call, String messagePart) {
    assertThatThrownBy(call::run).isInstanceOf(IllegalArgumentException.class).hasMessageContaining(messagePart);
  }

  // --- 조정 ---

  @Test
  @DisplayName("지급 — 미리보기 숫자와 반영 뒤 잔액이 같다(남음 12 → 42)")
  void grant_previewEqualsApplied() {
    store.weekly(ACCOUNT_ID, NOW, 100, 12);
    LocalDateTime weekEnd = PERIOD.end();

    CreditAdjustPreview preview = service.previewAdjust(MEMBER_ID, CreditAdjustType.GRANT, 30, weekEnd);
    CreditAdjustPreview applied = service.adjust(MEMBER_ID, CreditAdjustType.GRANT, 30, weekEnd, ADMIN, "시연 보상");

    assertThat(preview.availableBefore()).isEqualTo(12);
    assertThat(preview.availableAfter()).isEqualTo(42);
    assertThat(preview.summary()).isEqualTo("남음 12 → 42, 즉시 적용");
    assertThat(applied).isEqualTo(preview);
    assertThat(available()).isEqualTo(42);
    assertThat(store.grants).filteredOn(g -> g.getSource() == CreditGrantSource.ADMIN_BONUS).singleElement()
      .satisfies(g -> {
        assertThat(g.getAmount()).isEqualTo(30);
        assertThat(g.getRemaining()).isEqualTo(30);
        assertThat(g.getExpiresAt()).isEqualTo(weekEnd);
      });
    assertThat(store.ledgerOf(CreditLedgerType.ADJUST)).singleElement().satisfies(line -> {
      assertThat(line.getDelta()).isEqualTo(30);
      assertThat(line.getBalanceAfter()).isEqualTo(42);
      assertThat(line.getActor()).isEqualTo(ADMIN);
      assertThat(line.getReason()).contains("시연 보상");
    });
  }

  @Test
  @DisplayName("지급 — 계정이 없는 회원도 받는다(계정을 만든다)")
  void grant_createsAccountWhenMissing() {
    service.adjust("m2", CreditAdjustType.GRANT, 5, null, ADMIN, "첫 지급");

    assertThat(store.accounts).anyMatch(a -> "m2".equals(a.getMemberId()));
    assertThat(store.grants).singleElement().satisfies(g -> assertThat(g.getExpiresAt()).isNull());
  }

  @Test
  @DisplayName("차감 — 만료 임박 묶음부터 빼고 미리보기와 반영이 같다")
  void deduct_expiringFirst() {
    AiCreditGrant weekly = store.weekly(ACCOUNT_ID, NOW, 100, 3);
    AiCreditGrant bonus = store.grant(ACCOUNT_ID, CreditGrantSource.ADMIN_BONUS, 10, 10, NOW.minusDays(1), null);

    CreditAdjustPreview preview = service.previewAdjust(MEMBER_ID, CreditAdjustType.DEDUCT, 5, null);
    service.adjust(MEMBER_ID, CreditAdjustType.DEDUCT, 5, null, ADMIN, "중복 지급 회수");

    assertThat(preview.availableAfter()).isEqualTo(8);
    assertThat(available()).isEqualTo(8);
    assertThat(weekly.getRemaining()).isZero();
    assertThat(bonus.getRemaining()).isEqualTo(8);
    assertThat(store.ledgerOf(CreditLedgerType.ADJUST)).extracting(l -> l.getDelta()).containsExactly(-3, -2);
  }

  @Test
  @DisplayName("차감 — 사용 가능량(예약 제외)보다 많이는 뺄 수 없다. 아무것도 바뀌지 않는다")
  void deduct_cappedAtAvailable() {
    store.weekly(ACCOUNT_ID, NOW, 100, 12);
    store.reservedJob(ACCOUNT_ID, "k1", CreditJobKind.ROUTINE_CREATE, 2, NOW.minusMinutes(1));

    assertFormError(() -> service.previewAdjust(MEMBER_ID, CreditAdjustType.DEDUCT, 11, null), "10");
    assertFormError(() -> service.adjust(MEMBER_ID, CreditAdjustType.DEDUCT, 11, null, ADMIN, "회수"), "10");
    assertThat(store.ledger).isEmpty();
    assertThat(available()).isEqualTo(10);
  }

  @Test
  @DisplayName("사유가 비면 거절한다 — 아무것도 저장하지 않는다")
  void adjust_requiresReason() {
    store.weekly(ACCOUNT_ID, NOW, 100, 12);

    assertFormError(() -> service.adjust(MEMBER_ID, CreditAdjustType.GRANT, 5, null, ADMIN, "  "), "사유");
    assertThat(store.ledger).isEmpty();
    assertThat(store.grants).hasSize(1);
  }

  @Test
  @DisplayName("수량 0·음수, 지난 만료 시각은 폼 오류다")
  void adjust_rejectsBadAmountsAndPastExpiry() {
    assertFormError(() -> service.previewAdjust(MEMBER_ID, CreditAdjustType.GRANT, 0, null), "1 이상");
    assertFormError(() -> service.previewAdjust(MEMBER_ID, CreditAdjustType.DEDUCT, -3, null), "1 이상");
    assertFormError(() -> service.previewAdjust(MEMBER_ID, CreditAdjustType.GRANT, 3, NOW.minusHours(1)), "만료");
  }

  @Test
  @DisplayName("동결 — 상태만 바꾸고 delta 0 원장을 남긴다. 두 번 동결은 거절")
  void freeze_recordsAdjustLine() {
    store.weekly(ACCOUNT_ID, NOW, 100, 12);

    CreditAdjustPreview applied = service.adjust(MEMBER_ID, CreditAdjustType.FREEZE, 0, null, ADMIN, "남용 의심");

    assertThat(account.getStatus()).isEqualTo(CreditAccountStatus.FROZEN);
    assertThat(applied.summary()).isEqualTo("남음 12 → 12 · 동결, 즉시 적용");
    assertThat(store.ledgerOf(CreditLedgerType.ADJUST)).singleElement()
      .satisfies(line -> assertThat(line.getDelta()).isZero());
    assertFormError(() -> service.adjust(MEMBER_ID, CreditAdjustType.FREEZE, 0, null, ADMIN, "또"), "이미 동결");

    service.adjust(MEMBER_ID, CreditAdjustType.UNFREEZE, 0, null, ADMIN, "확인 완료");
    assertThat(account.getStatus()).isEqualTo(CreditAccountStatus.ACTIVE);
  }

  @Test
  @DisplayName("이번 주 말 만료는 다음 월요일 0시, 날짜는 그 날 끝, 무기한은 null")
  void resolveExpiry() {
    assertThat(service.resolveExpiry("WEEK_END", null)).isEqualTo(LocalDateTime.of(2026, 9, 28, 0, 0));
    assertThat(service.resolveExpiry(null, null)).isEqualTo(LocalDateTime.of(2026, 9, 28, 0, 0));
    assertThat(service.resolveExpiry("DATE", "2026-10-01")).isEqualTo(LocalDateTime.of(2026, 10, 2, 0, 0));
    assertThat(service.resolveExpiry("NONE", null)).isNull();
    assertFormError(() -> service.resolveExpiry("DATE", ""), "날짜");
    assertFormError(() -> service.resolveExpiry("DATE", "어제"), "날짜");
  }

  // --- 수동 반환 ---

  @Test
  @DisplayName("멈춘 예약 수동 반환 — RELEASED, RELEASE 원장에 관리자와 사유")
  void manualRelease_releasesReserved() {
    store.weekly(ACCOUNT_ID, NOW, 100, 10);
    AiCreditJob job = store.reservedJob(ACCOUNT_ID, "k1", CreditJobKind.ROUTINE_CREATE, 1, NOW.minusHours(2));

    String memberId = service.manualRelease(job.getId(), ADMIN, "서버 재시작으로 멈춤");

    assertThat(memberId).isEqualTo(MEMBER_ID);
    assertThat(job.getStatus()).isEqualTo(CreditJobStatus.RELEASED);
    assertThat(job.getFinishedAt()).isEqualTo(NOW);
    assertThat(available()).isEqualTo(10);
    assertThat(store.ledgerOf(CreditLedgerType.RELEASE)).singleElement().satisfies(line -> {
      assertThat(line.getDelta()).isEqualTo(1);
      assertThat(line.getBalanceAfter()).isEqualTo(10);
      assertThat(line.getActor()).isEqualTo(ADMIN);
      assertThat(line.getReason()).contains("서버 재시작으로 멈춤");
    });
  }

  @Test
  @DisplayName("수동 반환 — 사유가 없거나 이미 끝난 작업이면 폼 오류")
  void manualRelease_rejects() {
    AiCreditJob job = store.reservedJob(ACCOUNT_ID, "k1", CreditJobKind.ROUTINE_CREATE, 1, NOW.minusHours(2));

    assertFormError(() -> service.manualRelease(job.getId(), ADMIN, ""), "사유");
    job.setStatus(CreditJobStatus.SETTLED);
    assertFormError(() -> service.manualRelease(job.getId(), ADMIN, "반환"), "진행 중인 예약만");
    assertFormError(() -> service.manualRelease("nope", ADMIN, "반환"), "작업");
    assertThat(store.ledger).isEmpty();
  }

  @Test
  @DisplayName("사유가 200자를 넘으면 반환·조정·정책 발행 모두 폼 오류 — 500 으로 떨어지지 않는다")
  void adminReasons_rejectTooLong() {
    store.weekly(ACCOUNT_ID, NOW, 100, 10);
    AiCreditJob job = store.reservedJob(ACCOUNT_ID, "k1", CreditJobKind.ROUTINE_CREATE, 1, NOW.minusHours(2));
    String tooLong = "가".repeat(201);
    PolicyDraft base = draft(100, 100, AiCreditPolicy.GRANT_APPLY_NEXT_PERIOD);
    PolicyDraft longPolicy = new PolicyDraft(true, base.weeklyGrant(), base.actionCosts(), 15, base.grantApply(), tooLong);

    assertFormError(() -> service.manualRelease(job.getId(), ADMIN, tooLong), "200");
    assertFormError(() -> service.adjust(MEMBER_ID, CreditAdjustType.GRANT, 5, null, ADMIN, tooLong), "200");
    assertFormError(() -> service.publishPolicy(longPolicy, ADMIN), "200");
    assertThat(job.getStatus()).isEqualTo(CreditJobStatus.RESERVED);
    assertThat(store.ledger).isEmpty();
  }

  @Test
  @DisplayName("사유 200자는 받는다 — 반환 사유와 원장 사유가 컬럼(500) 안에 들어간다")
  void manualRelease_acceptsMaxReason() {
    AiCreditJob job = store.reservedJob(ACCOUNT_ID, "k1", CreditJobKind.ROUTINE_CREATE, 1, NOW.minusHours(2));

    service.manualRelease(job.getId(), ADMIN, "가".repeat(200));

    assertThat(job.getFailReason()).hasSizeLessThanOrEqualTo(500).endsWith("가");
    assertThat(store.ledgerOf(CreditLedgerType.RELEASE)).singleElement()
      .satisfies(line -> assertThat(line.getReason()).hasSizeLessThanOrEqualTo(500));
  }

  @Test
  @DisplayName("원장 사유는 컬럼(500)보다 길면 저장 직전에 자른다 — 시스템 사유도 막히지 않는다")
  void ledgerReason_truncatedToColumnLength() {
    AiCreditLedger line = new AiCreditLedger();

    line.setReason("가".repeat(600));

    assertThat(line.getReason()).hasSize(500);
  }

  // --- 정책 ---

  private static PolicyDraft draft(int free, int pro, String apply) {
    Map<PlanType, Integer> grants = new EnumMap<>(PlanType.class);
    grants.put(PlanType.FREE, free);
    grants.put(PlanType.PRO, pro);
    Map<CreditAction, Integer> costs = new EnumMap<>(CreditAction.class);
    costs.put(CreditAction.ROUTINE_TEXT, 1);
    costs.put(CreditAction.CARD_IMAGE, 1);
    costs.put(CreditAction.IMAGE_REGENERATE, 1);
    return new PolicyDraft(true, grants, costs, 15, apply, "지급량 조정");
  }

  @Test
  @DisplayName("NEXT_PERIOD — 이번 주 이미 준 지급은 그대로다")
  void publish_nextPeriodLeavesCurrentWeek() {
    AiCreditGrant weekly = store.weekly(ACCOUNT_ID, NOW, 100, 40);

    service.publishPolicy(draft(150, 150, AiCreditPolicy.GRANT_APPLY_NEXT_PERIOD), ADMIN);

    assertThat(weekly.getAmount()).isEqualTo(100);
    assertThat(weekly.getRemaining()).isEqualTo(40);
    assertThat(store.ledgerOf(CreditLedgerType.ADJUST)).isEmpty();
  }

  @Test
  @DisplayName("IMMEDIATE — 이번 주 지급에 차이만큼만 ADJUST 로 더한다(100 → 150 이면 +50)")
  void publish_immediateAddsDifference() {
    AiCreditGrant weekly = store.weekly(ACCOUNT_ID, NOW, 100, 40);

    AdminCreditService.PublishResult result =
      service.publishPolicy(draft(150, 150, AiCreditPolicy.GRANT_APPLY_IMMEDIATE), ADMIN);

    assertThat(result.adjustedAccounts()).isEqualTo(1);
    assertThat(result.policy().getVersion()).isEqualTo(2);
    assertThat(weekly.getAmount()).isEqualTo(150);
    assertThat(weekly.getRemaining()).isEqualTo(90);
    assertThat(store.ledgerOf(CreditLedgerType.ADJUST)).singleElement().satisfies(line -> {
      assertThat(line.getDelta()).isEqualTo(50);
      assertThat(line.getBalanceAfter()).isEqualTo(90);
      assertThat(line.getActor()).isEqualTo(ADMIN);
    });
  }

  @Test
  @DisplayName("IMMEDIATE — 줄이면 남은 양까지만 빼고 0 아래로 내려가지 않는다. Pro 는 Pro 지급량을 쓴다")
  void publish_immediateReducesButNotBelowZero() {
    AiCreditGrant free = store.weekly(ACCOUNT_ID, NOW, 100, 40);
    store.account("acc2", "pro-member");
    AiCreditGrant pro = store.weekly("acc2", NOW, 100, 100);
    when(subscriptionRepository.findMemberIdsWithEffectivePlan(any(), any(), any())).thenReturn(List.of("pro-member"));

    service.publishPolicy(draft(20, 120, AiCreditPolicy.GRANT_APPLY_IMMEDIATE), ADMIN);

    assertThat(free.getAmount()).isEqualTo(20);
    assertThat(free.getRemaining()).isZero();
    assertThat(pro.getAmount()).isEqualTo(120);
    assertThat(pro.getRemaining()).isEqualTo(120);
    assertThat(store.ledgerOf(CreditLedgerType.ADJUST)).extracting(l -> l.getDelta())
      .containsExactlyInAnyOrder(-40, 20);
  }

  @Test
  @DisplayName("정책 미리보기 — 지난 4주 사용이 0 이면 크레딧당 원가·예상 USD 는 null(0 나누기 방어)")
  void previewPolicy_zeroUsageGuard() {
    store.weekly(ACCOUNT_ID, NOW, 100, 100);
    when(accountRepository.findAll()).thenReturn(store.accounts);
    when(ledgerRepository.sumDeltaByAccount(any(), any(), any())).thenReturn(List.of());
    when(jobRepository.sumOverageByAccount(any(), any())).thenReturn(List.of());
    when(aiCallLogRepository.sumCostBetween(any(), any())).thenReturn(3.0);

    CreditPolicyPreview preview = service.previewPolicy(draft(150, 150, AiCreditPolicy.GRANT_APPLY_IMMEDIATE));

    assertThat(preview.usdPerCredit()).isNull();
    assertThat(preview.estimatedWeeklyUsdAfter()).isNull();
    assertThat(preview.targetAccounts()).isEqualTo(1);
    assertThat(preview.weeklyTotalBefore()).isEqualTo(100);
    assertThat(preview.weeklyTotalAfter()).isEqualTo(150);
    assertThat(preview.immediateAccounts()).isEqualTo(1);
    assertThat(preview.immediateDelta()).isEqualTo(50);
  }

  @Test
  @DisplayName("정책 미리보기 — 끄면 기존 횟수 한도 값을 함께 보여준다")
  void previewPolicy_disablingShowsOldLimits() {
    when(accountRepository.findAll()).thenReturn(List.of());
    when(ledgerRepository.sumDeltaByAccount(any(), any(), any())).thenReturn(List.of());
    when(jobRepository.sumOverageByAccount(any(), any())).thenReturn(List.of());
    when(systemConfigService.getInt(ConfigKey.FREE_ROUTINE_CREATE_PER_DAY)).thenReturn(2);
    when(systemConfigService.getInt(ConfigKey.FREE_ROUTINE_CREATE_PER_WEEK)).thenReturn(10);
    PolicyDraft off = draft(100, 100, AiCreditPolicy.GRANT_APPLY_NEXT_PERIOD);
    off = new PolicyDraft(false, off.weeklyGrant(), off.actionCosts(), 15, off.grantApply(), off.reason());

    CreditPolicyPreview preview = service.previewPolicy(off);

    assertThat(preview.disabling()).isTrue();
    assertThat(preview.freeRoutinePerDay()).isEqualTo(2);
    assertThat(preview.freeRoutinePerWeek()).isEqualTo(10);
  }

  @Test
  @DisplayName("크레딧당 원가 — 사용 0 이면 null, 아니면 USD ÷ 크레딧")
  void perCredit_guardsZero() {
    assertThat(AdminCreditQueryService.perCredit(1.5, 0)).isNull();
    assertThat(AdminCreditQueryService.perCredit(1.5, 3)).isEqualTo(0.5);
  }
}
