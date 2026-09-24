package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.request.CreditAdjustForm;
import com.chuseok22.elumserver.admin.application.dto.request.CreditAdjustType;
import com.chuseok22.elumserver.admin.application.dto.response.CreditAdjustPreview;
import com.chuseok22.elumserver.admin.application.dto.response.CreditPolicyPreview;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.application.service.CreditBalance;
import com.chuseok22.elumserver.credit.application.service.CreditPolicyService;
import com.chuseok22.elumserver.credit.application.service.PolicyDraft;
import com.chuseok22.elumserver.credit.core.CreditAccountStatus;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.core.CreditPeriod;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
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
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
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
 * 관리자 크레딧 쓰기 — 조정·수동 반환·정책 발행과 그 미리보기 (#407).
 *
 * <p>모든 쓰기는 계정 행을 잠근 안에서 하고 원장에 관리자 아이디(actor)와 사유를 남긴다. 미리보기와 반영은 같은
 * 잔액 계산({@link CreditAccountService#balance})을 거쳐 "미리보기에서 본 숫자 = 반영 뒤 숫자"가 된다.
 *
 * <p>폼 입력이 틀리면 {@link IllegalArgumentException}(화면에 그대로 보일 문구)을 던진다. 컨트롤러가 폼 오류로
 * 바꾼다 — 500 으로 떨어지지 않게.
 */
@Slf4j
@Service
public class AdminCreditService {

  /// 한 번에 지급·차감할 수 있는 상한. 0 을 하나 더 친 실수를 막는다.
  static final int MAX_ADJUST_AMOUNT = 10_000;
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
  private final MemberRepository memberRepository;
  private final SystemConfigService systemConfigService;
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 빠뜨리면 서버가 뜨지 않는다.
  @Autowired
  public AdminCreditService(
    CreditPolicyService policyService, CreditAccountService accountService,
    AiCreditAccountRepository accountRepository, AiCreditGrantRepository grantRepository,
    AiCreditJobRepository jobRepository, AiCreditLedgerRepository ledgerRepository,
    AiCallLogRepository aiCallLogRepository, SubscriptionRepository subscriptionRepository,
    MemberRepository memberRepository, SystemConfigService systemConfigService
  ) {
    this(policyService, accountService, accountRepository, grantRepository, jobRepository, ledgerRepository,
      aiCallLogRepository, subscriptionRepository, memberRepository, systemConfigService, Clock.systemDefaultZone());
  }

  AdminCreditService(
    CreditPolicyService policyService, CreditAccountService accountService,
    AiCreditAccountRepository accountRepository, AiCreditGrantRepository grantRepository,
    AiCreditJobRepository jobRepository, AiCreditLedgerRepository ledgerRepository,
    AiCallLogRepository aiCallLogRepository, SubscriptionRepository subscriptionRepository,
    MemberRepository memberRepository, SystemConfigService systemConfigService, Clock clock
  ) {
    this.policyService = policyService;
    this.accountService = accountService;
    this.accountRepository = accountRepository;
    this.grantRepository = grantRepository;
    this.jobRepository = jobRepository;
    this.ledgerRepository = ledgerRepository;
    this.aiCallLogRepository = aiCallLogRepository;
    this.subscriptionRepository = subscriptionRepository;
    this.memberRepository = memberRepository;
    this.systemConfigService = systemConfigService;
    this.clock = clock;
  }

  // --- 조정 ---

  /**
   * 조정 결과를 미리 계산한다. 아무것도 쓰지 않는다(계정이 없으면 잔액 0 으로 본다).
   *
   * @throws IllegalArgumentException 수량·만료·차감 상한·동결 상태가 맞지 않을 때
   */
  @Transactional(readOnly = true)
  public CreditAdjustPreview previewAdjust(String memberId, CreditAdjustType type, int amount, LocalDateTime expiresAt) {
    requireMember(memberId);
    LocalDateTime now = LocalDateTime.now(clock);
    AiCreditAccount account = accountRepository.findByMemberId(memberId).orElse(null);
    int available = account == null ? 0 : accountService.balance(account, now).available();
    boolean frozen = account != null && account.isFrozen();
    return preview(type, amount, expiresAt, available, frozen, now);
  }

  /**
   * 조정을 반영한다. 계정을 잠근 안에서 미리보기와 같은 계산을 다시 한다 — 그 사이 잔액이 바뀌었으면
   * 반영 결과가 그 값을 따른다(돌려주는 값이 실제로 반영된 숫자다).
   *
   * @return 반영된 결과
   * @throws IllegalArgumentException 사유가 비었거나 미리보기와 같은 검사에 걸릴 때
   */
  @Transactional
  public CreditAdjustPreview adjust(
    String memberId, CreditAdjustType type, int amount, LocalDateTime expiresAt, String actor, String reason
  ) {
    String cleanReason = requireReason(reason);
    requireMember(memberId);
    LocalDateTime now = LocalDateTime.now(clock);
    AiCreditAccount account = accountService.lockAccount(memberId);
    CreditBalance before = accountService.balance(account, now);
    CreditAdjustPreview result = preview(type, amount, expiresAt, before.available(), account.isFrozen(), now);
    Integer policyVersion = currentPolicyVersion();
    String ledgerReason = "[" + type.getLabel() + "] " + cleanReason;

    switch (type) {
      case GRANT -> {
        AiCreditGrant grant = new AiCreditGrant();
        grant.setAccountId(account.getId());
        grant.setSource(CreditGrantSource.ADMIN_BONUS);
        grant.setAmount(amount);
        grant.setRemaining(amount);
        grant.setValidFrom(now);
        grant.setExpiresAt(expiresAt);
        grant.setPolicyVersion(policyVersion);
        grant.setRefId("admin:" + actor);
        AiCreditGrant saved = grantRepository.save(grant);
        AiCreditLedger line = ledgerLine(account.getId(), CreditLedgerType.ADJUST, amount,
          before.available() + amount, actor, ledgerReason);
        line.setGrantId(saved.getId());
        line.setPolicyVersion(policyVersion);
        ledgerRepository.save(line);
      }
      case DEDUCT -> {
        int left = amount;
        int running = before.available();
        for (AiCreditGrant grant : accountService.spendableGrants(account.getId(), now)) {
          if (left == 0) {
            break;
          }
          int take = Math.min(left, grant.getRemaining());
          grant.setRemaining(grant.getRemaining() - take);
          grantRepository.save(grant);
          left -= take;
          running -= take;
          AiCreditLedger line = ledgerLine(account.getId(), CreditLedgerType.ADJUST, -take, running, actor, ledgerReason);
          line.setGrantId(grant.getId());
          line.setPolicyVersion(policyVersion);
          ledgerRepository.save(line);
        }
      }
      case FREEZE, UNFREEZE -> {
        account.setStatus(type == CreditAdjustType.FREEZE ? CreditAccountStatus.FROZEN : CreditAccountStatus.ACTIVE);
        accountRepository.save(account);
        // 잔액은 그대로지만 누가 왜 막았는지는 원장에 남아야 한다.
        AiCreditLedger line = ledgerLine(account.getId(), CreditLedgerType.ADJUST, 0, before.available(), actor,
          ledgerReason);
        line.setPolicyVersion(policyVersion);
        ledgerRepository.save(line);
      }
    }
    log.info("관리자 크레딧 조정: memberId={}, type={}, amount={}, {} → {}, actor={}",
      memberId, type, amount, result.availableBefore(), result.availableAfter(), actor);
    return result;
  }

  /**
   * 폼의 만료 선택을 시각으로 바꾼다. 이번 주 말 = 다음 월요일 0시, 날짜 = 그 날 끝(다음 날 0시), 무기한 = null.
   *
   * @throws IllegalArgumentException 날짜를 고르고 비웠거나 형식이 틀릴 때
   */
  public LocalDateTime resolveExpiry(String mode, String date) {
    String chosen = (mode == null || mode.isBlank()) ? CreditAdjustForm.EXPIRY_WEEK_END : mode.trim();
    return switch (chosen) {
      case CreditAdjustForm.EXPIRY_NONE -> null;
      case CreditAdjustForm.EXPIRY_DATE -> {
        if (date == null || date.isBlank()) {
          throw new IllegalArgumentException("만료 날짜를 골라주세요.");
        }
        try {
          yield LocalDate.parse(date.trim()).plusDays(1).atStartOfDay();
        } catch (DateTimeParseException e) {
          throw new IllegalArgumentException("만료 날짜 형식이 올바르지 않아요: " + date);
        }
      }
      default -> CreditPeriod.of(LocalDateTime.now(clock)).end();
    };
  }

  /**
   * 사유는 모든 관리자 쓰기에 필수다 — 나중에 "이건 왜 줬지"에 답해야 한다.
   *
   * <p>길이도 여기서 막는다. 원장·작업 사유 컬럼(500)을 넘기면 저장이 DB 오류(500 화면)로 떨어진다 — 폼
   * 오류로 돌려 관리자가 줄여 다시 적게 한다.
   */
  public static String requireReason(String reason) {
    if (reason == null || reason.isBlank()) {
      throw new IllegalArgumentException("사유를 적어주세요.");
    }
    String trimmed = reason.trim();
    if (trimmed.length() > CreditPolicyService.ADMIN_REASON_MAX_LENGTH) {
      throw new IllegalArgumentException("사유는 " + CreditPolicyService.ADMIN_REASON_MAX_LENGTH + "자까지 적을 수 있어요.");
    }
    return trimmed;
  }

  private CreditAdjustPreview preview(
    CreditAdjustType type, int amount, LocalDateTime expiresAt, int available, boolean frozen, LocalDateTime now
  ) {
    if (type == null) {
      throw new IllegalArgumentException("조정 종류를 골라주세요.");
    }
    if (type.hasAmount()) {
      if (amount < 1) {
        throw new IllegalArgumentException("수량은 1 이상이어야 해요.");
      }
      if (amount > MAX_ADJUST_AMOUNT) {
        throw new IllegalArgumentException("한 번에 " + MAX_ADJUST_AMOUNT + " 까지 조정할 수 있어요.");
      }
    }
    return switch (type) {
      case GRANT -> {
        if (expiresAt != null && !expiresAt.isAfter(now)) {
          throw new IllegalArgumentException("만료 시각은 지금 이후여야 해요.");
        }
        yield new CreditAdjustPreview(type, amount, available, available + amount, expiresAt, frozen, frozen);
      }
      case DEDUCT -> {
        // 예약 중인 몫은 뺄 수 없다 — 빼면 정산 때 차감할 묶음이 모자라 초과로 샌다.
        if (amount > available) {
          throw new IllegalArgumentException("남은 크레딧(" + available + ")보다 많이 뺄 수 없어요.");
        }
        yield new CreditAdjustPreview(type, amount, available, available - amount, null, frozen, frozen);
      }
      case FREEZE -> {
        if (frozen) {
          throw new IllegalArgumentException("이미 동결된 계정이에요.");
        }
        yield new CreditAdjustPreview(type, 0, available, available, null, false, true);
      }
      case UNFREEZE -> {
        if (!frozen) {
          throw new IllegalArgumentException("동결된 계정이 아니에요.");
        }
        yield new CreditAdjustPreview(type, 0, available, available, null, true, false);
      }
    };
  }

  // --- 수동 반환 ---

  /**
   * 멈춘 예약을 손으로 돌려준다. RESERVED 일 때만.
   *
   * <p>{@code CreditReservationService.release} 를 쓰지 않는다 — 그쪽은 실패를 삼키고 원장 actor 가 system 이다.
   * 관리자 반환은 실패가 화면에 보여야 하고 누가 풀었는지 남아야 한다.
   *
   * @return 작업의 회원 id (화면을 돌아갈 곳). 떼어진 계정이면 null
   * @throws IllegalArgumentException 사유가 없거나 작업이 없거나 이미 끝났을 때
   */
  @Transactional
  public String manualRelease(String jobId, String actor, String reason) {
    String cleanReason = requireReason(reason);
    // 계정을 잠근 뒤에 작업을 읽는다 — 먼저 읽으면 그 사이 정산된 것을 못 본다.
    String accountId = jobRepository.findAccountIdById(jobId)
      .orElseThrow(() -> new IllegalArgumentException("작업을 찾을 수 없어요: " + jobId));
    AiCreditAccount account = accountService.lockAccountById(accountId);
    AiCreditJob job = jobRepository.findById(jobId)
      .orElseThrow(() -> new IllegalArgumentException("작업을 찾을 수 없어요: " + jobId));
    if (job.getStatus() != CreditJobStatus.RESERVED) {
      throw new IllegalArgumentException("진행 중인 예약만 반환할 수 있어요. 지금 상태: " + job.getStatus().name());
    }
    LocalDateTime now = LocalDateTime.now(clock);
    int balanceAfter = accountService.balance(account, now).available() + job.getReserved();
    job.setStatus(CreditJobStatus.RELEASED);
    job.setFinishedAt(now);
    job.setFailReason("관리자 반환: " + cleanReason);
    jobRepository.save(job);

    AiCreditLedger line = ledgerLine(accountId, CreditLedgerType.RELEASE, job.getReserved(), balanceAfter, actor,
      "[관리자 반환] " + cleanReason);
    line.setJobId(jobId);
    line.setPolicyVersion(job.getPolicyVersion());
    ledgerRepository.save(line);
    log.info("관리자 크레딧 예약 수동 반환: jobId={}, accountId={}, actor={}", jobId, accountId, actor);
    return account.getMemberId();
  }

  // --- 정책 ---

  /// 발행 결과. adjustedAccounts 는 IMMEDIATE 로 이번 주 지급을 고친 계정 수.
  public record PublishResult(AiCreditPolicy policy, int adjustedAccounts) {

  }

  /**
   * 새 정책을 발행한다. IMMEDIATE 면 이번 주 이미 준 주간 지급을 새 지급량으로 맞춘다.
   *
   * <p>늘리면 차이만큼 더하고, 줄이면 남은 양까지만 뺀다(0 아래로 내려가지 않는다). 계정마다 잠근 뒤 묶음을
   * 읽어 그 사이 정산과 엇갈리지 않게 한다. 한 트랜잭션이라 도중에 실패하면 발행까지 함께 되돌린다.
   *
   * @throws IllegalArgumentException 사유·숫자·적용 시점이 틀릴 때 (정책 서비스 검사)
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
      AiCreditLedger line = ledgerLine(accountId, CreditLedgerType.ADJUST, delta, balanceAfter, actor,
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

  // --- 공통 ---

  /// 지금 Pro 로 동작하는 회원 — 계정마다 planOf 를 부르지 않으려고 한 번에 읽는다.
  private Set<String> proMemberIds(LocalDateTime now) {
    return new HashSet<>(subscriptionRepository.findMemberIdsWithEffectivePlan(
      PlanType.PRO, SubscriptionStatus.ACTIVE, now));
  }

  /// 떼어진 계정(회원 없음)은 Free 로 본다 — 예약 서비스와 같은 규칙.
  private static PlanType planOf(String memberId, Set<String> proMembers) {
    return memberId != null && proMembers.contains(memberId) ? PlanType.PRO : PlanType.FREE;
  }

  private void requireMember(String memberId) {
    if (memberId == null || !memberRepository.existsById(memberId)) {
      throw new CustomException(ErrorCode.MEMBER_NOT_FOUND);
    }
  }

  private Integer currentPolicyVersion() {
    AiCreditPolicy policy = policyService.current();
    return policy.getVersion() > 0 ? policy.getVersion() : null;
  }

  private static AiCreditLedger ledgerLine(
    String accountId, CreditLedgerType type, int delta, int balanceAfter, String actor, String reason
  ) {
    AiCreditLedger line = new AiCreditLedger();
    line.setAccountId(accountId);
    line.setType(type);
    line.setDelta(delta);
    line.setBalanceAfter(Math.max(0, balanceAfter));
    line.setActor(actor == null || actor.isBlank() ? "admin" : actor);
    line.setReason(reason != null && reason.length() > 500 ? reason.substring(0, 500) : reason);
    return line;
  }
}
