package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.CreditPolicyPreview;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.application.service.CreditPolicyService;
import com.chuseok22.elumserver.credit.application.service.PolicyDraft;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.core.CreditPeriod;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository.AccountOverage;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository.AccountTotal;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionStatus;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 관리자 크레딧 정책 쓰기: 발행(즉시 적용 포함), 발행 영향 미리보기, 현재 정책·이력 조회
 * 계정마다 잠근 안에서 이번 주 지급을 고치고 원장에 관리자 아이디(actor)와 사유를 남김
 */
@Slf4j
@Service
public class AdminCreditPolicyService {

  /// 정책 미리보기가 보는 지난 주 수.
  static final int PREVIEW_WEEKS = 4;

  private final CreditPolicyService policyService;
  private final CreditAccountService accountService;
  private final AiCreditAccountRepository accountRepository;
  private final AiCreditGrantRepository grantRepository;
  private final AiCreditJobRepository jobRepository;
  private final AiCreditLedgerRepository ledgerRepository;
  private final AiCallLogRepository aiCallLogRepository;
  private final SubscriptionRepository subscriptionRepository;
  private final SystemConfigService systemConfigService;
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 빠뜨리면 서버가 뜨지 않는다.
  @Autowired
  public AdminCreditPolicyService(
    CreditPolicyService policyService, CreditAccountService accountService,
    AiCreditAccountRepository accountRepository, AiCreditGrantRepository grantRepository,
    AiCreditJobRepository jobRepository, AiCreditLedgerRepository ledgerRepository,
    AiCallLogRepository aiCallLogRepository, SubscriptionRepository subscriptionRepository,
    SystemConfigService systemConfigService
  ) {
    this(policyService, accountService, accountRepository, grantRepository, jobRepository, ledgerRepository,
      aiCallLogRepository, subscriptionRepository, systemConfigService, Clock.systemDefaultZone());
  }

  AdminCreditPolicyService(
    CreditPolicyService policyService, CreditAccountService accountService,
    AiCreditAccountRepository accountRepository, AiCreditGrantRepository grantRepository,
    AiCreditJobRepository jobRepository, AiCreditLedgerRepository ledgerRepository,
    AiCallLogRepository aiCallLogRepository, SubscriptionRepository subscriptionRepository,
    SystemConfigService systemConfigService, Clock clock
  ) {
    this.policyService = policyService;
    this.accountService = accountService;
    this.accountRepository = accountRepository;
    this.grantRepository = grantRepository;
    this.jobRepository = jobRepository;
    this.ledgerRepository = ledgerRepository;
    this.aiCallLogRepository = aiCallLogRepository;
    this.subscriptionRepository = subscriptionRepository;
    this.systemConfigService = systemConfigService;
    this.clock = clock;
  }

  /// 발행 결과. adjustedAccounts 는 IMMEDIATE 로 이번 주 지급을 고친 계정 수.
  public record PublishResult(AiCreditPolicy policy, int adjustedAccounts) {

  }

  /**
   * 새 정책을 발행한다. IMMEDIATE 면 이번 주 이미 준 주간 지급을 새 지급량으로 맞춘다.
   *
   * <p>늘리면 차이만큼 더하고, 줄이면 남은 양까지만 뺀다(0 아래로 내려가지 않는다). 계정마다 잠근 뒤 묶음을
   * 읽어 그 사이 정산과 엇갈리지 않게 한다. 한 트랜잭션이라 도중에 실패하면 발행까지 함께 되돌린다.
   *
   * @throws CustomException 사유·숫자·적용 시점이 틀릴 때 (정책 서비스 검사)
   */
  @Transactional
  public PublishResult publishPolicy(PolicyDraft draft, String actor) {
    AiCreditPolicy published = policyService.publish(draft, actor);
    int adjusted = 0;
    if (AiCreditPolicy.GRANT_APPLY_IMMEDIATE.equals(draft.grantApply())) {
      adjusted = applyToCurrentWeek(published, actor, draft.reason());
    }
    log.info("관리자 크레딧 정책 발행: version={}, apply={}, adjustedAccounts={}, actor={}",
      published.getVersion(), draft.grantApply(), adjusted, actor);
    return new PublishResult(published, adjusted);
  }

  private int applyToCurrentWeek(AiCreditPolicy published, String actor, String reason) {
    LocalDateTime now = LocalDateTime.now(clock);
    CreditPeriod period = CreditPeriod.of(now);
    Set<String> proMembers = proMemberIds(now);
    int adjusted = 0;
    for (String accountId : grantRepository.findAccountIdsByPeriodKeyAndSource(period.key(), CreditGrantSource.WEEKLY)) {
      AiCreditAccount account = accountService.lockAccountById(accountId);
      AiCreditGrant grant = grantRepository.findByAccountIdAndPeriodKey(accountId, period.key()).orElse(null);
      if (grant == null) {
        continue;
      }
      int newAmount = published.weeklyGrantFor(planOf(account.getMemberId(), proMembers));
      int diff = newAmount - grant.getAmount();
      if (diff == 0) {
        continue;
      }
      int delta = diff > 0 ? diff : -Math.min(-diff, grant.getRemaining());
      grant.setAmount(newAmount);
      grant.setRemaining(grant.getRemaining() + delta);
      grant.setPolicyVersion(published.getVersion());
      grantRepository.save(grant);
      adjusted++;
      if (delta == 0) {
        // 이미 다 써서 뺄 것이 없다. 지급량 숫자만 바뀌고 잔액은 그대로다.
        continue;
      }
      int balanceAfter = accountService.balance(account, now).available();
      AiCreditLedger line = AdminCreditLedgerLine.of(accountId, CreditLedgerType.ADJUST, delta, balanceAfter, actor,
        "[정책 v" + published.getVersion() + " 즉시 적용] " + reason);
      line.setGrantId(grant.getId());
      line.setPolicyVersion(published.getVersion());
      ledgerRepository.save(line);
    }
    return adjusted;
  }

  /**
   * 정책 발행의 영향을 추정한다. 아무것도 쓰지 않는다.
   *
   * <p>지난 4주 계정별 주 수요(실제 차감 + 초과)를 새 지급량에 대 본다. 단가 변경은 수요에 반영하지 않는다 —
   * 수요는 옛 단가로 센 크레딧이다.
   */
  @Transactional(readOnly = true)
  public CreditPolicyPreview previewPolicy(PolicyDraft draft) {
    LocalDateTime now = LocalDateTime.now(clock);
    CreditPeriod thisWeek = CreditPeriod.of(now);
    AiCreditPolicy current = policyService.current();
    Set<String> proMembers = proMemberIds(now);

    Map<String, PlanType> planByAccount = new HashMap<>();
    long proAccounts = 0;
    for (AiCreditAccount account : accountRepository.findAll()) {
      if (account.getMemberId() == null) {
        continue;
      }
      PlanType plan = planOf(account.getMemberId(), proMembers);
      planByAccount.put(account.getId(), plan);
      if (plan == PlanType.PRO) {
        proAccounts++;
      }
    }
    long target = planByAccount.size();
    long freeAccounts = target - proAccounts;
    int oldFree = current.weeklyGrantFor(PlanType.FREE);
    int oldPro = current.weeklyGrantFor(PlanType.PRO);
    int newFree = grantOf(draft, PlanType.FREE);
    int newPro = grantOf(draft, PlanType.PRO);

    // 지난 4주 수요.
    long exhaustedOld = 0;
    long exhaustedNew = 0;
    long usedOld = 0;
    long usedNew = 0;
    long usedTotal = 0;
    for (int back = PREVIEW_WEEKS; back >= 1; back--) {
      LocalDateTime from = thisWeek.start().minusWeeks(back);
      LocalDateTime to = from.plusWeeks(1);
      Map<String, Long> demand = new HashMap<>();
      for (AccountTotal consumed : ledgerRepository.sumDeltaByAccount(CreditLedgerType.CONSUME, from, to)) {
        demand.merge(consumed.getAccountId(), -consumed.getTotal(), Long::sum);
        usedTotal += -consumed.getTotal();
      }
      for (AccountOverage over : jobRepository.sumOverageByAccount(from, to)) {
        demand.merge(over.getAccountId(), over.getTotal(), Long::sum);
      }
      for (Map.Entry<String, Long> entry : demand.entrySet()) {
        boolean pro = planByAccount.get(entry.getKey()) == PlanType.PRO;
        long want = entry.getValue();
        int oldGrant = pro ? oldPro : oldFree;
        int newGrant = pro ? newPro : newFree;
        if (want > 0 && want >= oldGrant) {
          exhaustedOld++;
        }
        if (want > 0 && want >= newGrant) {
          exhaustedNew++;
        }
        usedOld += Math.min(want, oldGrant);
        usedNew += Math.min(want, newGrant);
      }
    }
    double usd = aiCallLogRepository.sumCostBetween(thisWeek.start().minusWeeks(PREVIEW_WEEKS), thisWeek.start());
    Double usdPerCredit = AdminCreditQueryService.perCredit(usd, usedTotal);

    // IMMEDIATE 로 이번 주 지급을 고칠 계정과 총량 변화(읽기만).
    boolean immediate = AiCreditPolicy.GRANT_APPLY_IMMEDIATE.equals(draft.grantApply());
    long immediateAccounts = 0;
    long immediateDelta = 0;
    if (immediate) {
      Map<String, String> memberByAccount = new HashMap<>();
      for (AiCreditAccount account : accountRepository.findAll()) {
        memberByAccount.put(account.getId(), account.getMemberId());
      }
      for (AiCreditGrant grant : grantRepository.findByPeriodKey(thisWeek.key())) {
        if (grant.getSource() != CreditGrantSource.WEEKLY) {
          continue;
        }
        int diff = grantOf(draft, planOf(memberByAccount.get(grant.getAccountId()), proMembers)) - grant.getAmount();
        if (diff != 0) {
          immediateAccounts++;
          immediateDelta += diff;
        }
      }
    }

    boolean disabling = current.isEnabled() && !draft.enabled();
    return new CreditPolicyPreview(
      draft,
      target,
      freeAccounts,
      proAccounts,
      freeAccounts * oldFree + proAccounts * oldPro,
      freeAccounts * newFree + proAccounts * newPro,
      (double) exhaustedOld / PREVIEW_WEEKS,
      (double) exhaustedNew / PREVIEW_WEEKS,
      usdPerCredit,
      usdPerCredit == null ? null : usdPerCredit * usedOld / PREVIEW_WEEKS,
      usdPerCredit == null ? null : usdPerCredit * usedNew / PREVIEW_WEEKS,
      immediate,
      immediateAccounts,
      immediateDelta,
      disabling,
      systemConfigService.getInt(ConfigKey.FREE_ROUTINE_CREATE_PER_DAY),
      systemConfigService.getInt(ConfigKey.FREE_ROUTINE_CREATE_PER_WEEK)
    );
  }

  private static int grantOf(PolicyDraft draft, PlanType plan) {
    Integer value = draft.weeklyGrant() == null ? null : draft.weeklyGrant().get(plan);
    return value == null ? 0 : value;
  }

  /// 지금 유효한 정책(정책 화면 카드).
  public AiCreditPolicy currentPolicy() {
    return policyService.current();
  }

  /// 버전 이력, 최신부터.
  public List<AiCreditPolicy> policyHistory() {
    return policyService.history();
  }

  /// 지금 Pro 로 동작하는 회원 — 계정마다 planOf 를 부르지 않으려고 한 번에 읽는다.
  private Set<String> proMemberIds(LocalDateTime now) {
    return new HashSet<>(subscriptionRepository.findMemberIdsWithEffectivePlan(
      PlanType.PRO, SubscriptionStatus.ACTIVE, now));
  }

  /// 떼어진 계정(회원 없음)은 Free 로 본다 — 예약 서비스와 같은 규칙.
  private static PlanType planOf(String memberId, Set<String> proMembers) {
    return memberId != null && proMembers.contains(memberId) ? PlanType.PRO : PlanType.FREE;
  }
}
