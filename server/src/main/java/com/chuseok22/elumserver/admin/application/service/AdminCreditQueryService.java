package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditJobRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditMemberDetail;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditOverview;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditWeekRow;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.CreditJobCost;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.application.service.CreditPolicyService;
import com.chuseok22.elumserver.credit.core.CreditAccountStatus;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
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
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository.AccountLastAt;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository.AccountTotal;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionStatus;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.routine.application.service.AiDailyBudgetGuard;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Subquery;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.IsoFields;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 관리자 크레딧 화면의 읽기 — 개요·회원별 표·회원 상세·작업 탐색 (#407).
 *
 * <p>회원 수만큼 쿼리를 내지 않는다. 한 주의 계정별 값은 group by 몇 번으로 받아 메모리에서 합친다
 * ({@link #weekRows}). 정렬이 계산값(사용·초과·남음)이라 페이지 자르기도 메모리에서 한다 — 계정 수가 수천을
 * 넘으면 SQL 로 옮길 자리다.
 *
 * <p>읽기만 한다. 이번 주 지급 보장·멈춘 예약 정리처럼 조회가 쓰기를 일으키는 경로(CreditQueryService)는 부르지
 * 않는다 — 관리자가 화면을 여는 것만으로 회원 장부가 바뀌면 안 된다.
 */
@Slf4j
@Service
@Transactional(readOnly = true)
public class AdminCreditQueryService {

  static final int PAGE_SIZE = 20;
  private static final Pattern WEEK_KEY = Pattern.compile("(\\d{4})-W(\\d{2})");

  private final CreditPolicyService policyService;
  private final CreditAccountService accountService;
  private final AiCreditAccountRepository accountRepository;
  private final AiCreditGrantRepository grantRepository;
  private final AiCreditJobRepository jobRepository;
  private final AiCreditLedgerRepository ledgerRepository;
  private final AiCallLogRepository aiCallLogRepository;
  private final SubscriptionRepository subscriptionRepository;
  private final MemberRepository memberRepository;
  private final ProfileGuardianRepository profileGuardianRepository;
  private final EntitlementService entitlementService;
  private final AiDailyBudgetGuard dailyBudgetGuard;
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 빠뜨리면 서버가 뜨지 않는다.
  @Autowired
  public AdminCreditQueryService(
    CreditPolicyService policyService, CreditAccountService accountService,
    AiCreditAccountRepository accountRepository, AiCreditGrantRepository grantRepository,
    AiCreditJobRepository jobRepository, AiCreditLedgerRepository ledgerRepository,
    AiCallLogRepository aiCallLogRepository, SubscriptionRepository subscriptionRepository,
    MemberRepository memberRepository, ProfileGuardianRepository profileGuardianRepository,
    EntitlementService entitlementService, AiDailyBudgetGuard dailyBudgetGuard
  ) {
    this(policyService, accountService, accountRepository, grantRepository, jobRepository, ledgerRepository,
      aiCallLogRepository, subscriptionRepository, memberRepository, profileGuardianRepository,
      entitlementService, dailyBudgetGuard, Clock.systemDefaultZone());
  }

  AdminCreditQueryService(
    CreditPolicyService policyService, CreditAccountService accountService,
    AiCreditAccountRepository accountRepository, AiCreditGrantRepository grantRepository,
    AiCreditJobRepository jobRepository, AiCreditLedgerRepository ledgerRepository,
    AiCallLogRepository aiCallLogRepository, SubscriptionRepository subscriptionRepository,
    MemberRepository memberRepository, ProfileGuardianRepository profileGuardianRepository,
    EntitlementService entitlementService, AiDailyBudgetGuard dailyBudgetGuard, Clock clock
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
    this.profileGuardianRepository = profileGuardianRepository;
    this.entitlementService = entitlementService;
    this.dailyBudgetGuard = dailyBudgetGuard;
    this.clock = clock;
  }

  /// USD ÷ 크레딧. 크레딧이 0 이면 null — 0 으로 나눠 무한대·NaN 이 화면에 뜨지 않게.
  public static Double perCredit(double usd, long credits) {
    return credits <= 0 ? null : usd / credits;
  }

  /**
   * 주 키(2026-W39)를 주기로 바꾼다. 비었거나 틀리면 이번 주, 미래 주면 이번 주로 되돌린다.
   */
  public CreditPeriod periodOf(String key) {
    LocalDateTime now = LocalDateTime.now(clock);
    CreditPeriod current = CreditPeriod.of(now);
    if (key == null || key.isBlank()) {
      return current;
    }
    Matcher matcher = WEEK_KEY.matcher(key.trim());
    if (!matcher.matches()) {
      return current;
    }
    try {
      int year = Integer.parseInt(matcher.group(1));
      int week = Integer.parseInt(matcher.group(2));
      // ISO 주 연도의 1월 4일은 언제나 그 해 첫 주에 있다.
      LocalDate monday = LocalDate.of(year, 1, 4)
        .with(IsoFields.WEEK_OF_WEEK_BASED_YEAR, week)
        .with(DayOfWeek.MONDAY);
      CreditPeriod period = CreditPeriod.of(monday.atStartOfDay());
      return period.start().isAfter(current.start()) ? current : period;
    } catch (RuntimeException e) {
      return current;
    }
  }

  // --- 개요 ---

  public AdminCreditOverview overview(String weekKey) {
    LocalDateTime now = LocalDateTime.now(clock);
    CreditPeriod period = periodOf(weekKey);
    boolean current = period.contains(now);
    AiCreditPolicy policy = policyService.current();
    List<AdminCreditWeekRow> rows = weekRows(period, now);

    long active = rows.stream().filter(row -> row.weeklyGrant() != null).count();
    long granted = rows.stream().mapToLong(row -> row.weeklyGrant() == null ? 0 : row.weeklyGrant()).sum();
    long bonus = rows.stream().mapToLong(AdminCreditWeekRow::bonus).sum();
    long used = rows.stream().mapToLong(AdminCreditWeekRow::used).sum();
    long reserved = rows.stream().mapToLong(AdminCreditWeekRow::reserved).sum();
    long remaining = rows.stream().mapToLong(AdminCreditWeekRow::remaining).sum();
    long overageJobs = rows.stream().mapToLong(AdminCreditWeekRow::overageJobs).sum();
    long overageCredits = rows.stream().mapToLong(AdminCreditWeekRow::overage).sum();
    long exhausted = rows.stream().filter(AdminCreditWeekRow::exhausted).count();
    // 반환 수는 작업 상태로 센다 — 원장 RELEASE 는 정산 때도 한 줄씩 생긴다.
    long released = jobRepository.countByStatusInAndFinishedAtGreaterThanEqualAndFinishedAtLessThan(
      List.of(CreditJobStatus.RELEASED, CreditJobStatus.EXPIRED), period.start(), period.end());

    List<AdminCreditOverview.ModelCost> models = aiCallLogRepository
      .sumCostByModelBetween(period.start(), period.end()).stream()
      .map(cost -> new AdminCreditOverview.ModelCost(
        cost.getModel() == null ? "(모델 없음)" : cost.getModel(), cost.getCallCount(), cost.getTotalCostUsd()))
      .sorted(Comparator.comparingDouble(AdminCreditOverview.ModelCost::usd).reversed())
      .toList();
    double totalUsd = models.stream().mapToDouble(AdminCreditOverview.ModelCost::usd).sum();
    List<AdminCreditOverview.KindCost> kinds = jobRepository
      .sumCostByKind(CreditJobStatus.SETTLED, period.start(), period.end()).stream()
      .filter(cost -> cost.getJobCount() > 0)
      .map(cost -> new AdminCreditOverview.KindCost(
        cost.getKind(), cost.getJobCount(), cost.getCallCount(), cost.getTotalCostUsd()))
      .toList();

    long stuck = jobRepository.countByStatusAndStartedAtBefore(CreditJobStatus.RESERVED, stuckThreshold(policy, now));
    long mismatch = jobRepository.countSettledWithoutCallLog(CreditJobStatus.SETTLED, period.start(), period.end());

    CreditPeriod prev = CreditPeriod.of(period.start().minusWeeks(1));
    String nextKey = current ? null : CreditPeriod.of(period.end()).key();
    return new AdminCreditOverview(period, prev.key(), nextKey, current, active, granted, bonus, used, reserved,
      remaining, overageJobs, overageCredits, released, exhausted, totalUsd, perCredit(totalUsd, used), models, kinds,
      stuck, mismatch, budgetReached(), policy);
  }

  // --- 회원별 ---

  /// 정렬 기준. 기본은 사용 많은 순.
  public enum MemberSort {
    USED_DESC, OVERAGE_DESC, REMAINING_ASC;

    public static MemberSort of(String raw) {
      if (raw != null) {
        for (MemberSort sort : values()) {
          if (sort.name().equalsIgnoreCase(raw.trim())) {
            return sort;
          }
        }
      }
      return USED_DESC;
    }
  }

  /// 회원별 표 필터. 셋 다 켜면 모두 만족하는 계정만.
  public record MemberFilter(String keyword, boolean exhaustedOnly, boolean overageOnly, boolean frozenOnly) {

  }

  public Page<AdminCreditWeekRow> members(String weekKey, MemberFilter filter, MemberSort sort, int page) {
    LocalDateTime now = LocalDateTime.now(clock);
    CreditPeriod period = periodOf(weekKey);
    List<AdminCreditWeekRow> rows = weekRows(period, now);

    String keyword = filter.keyword() == null ? "" : filter.keyword().trim();
    if (!keyword.isEmpty()) {
      Set<String> memberIds = new HashSet<>(memberRepository.findIdsByKeyword(keyword));
      rows = rows.stream()
        .filter(row -> keyword.equals(row.accountId()) || (row.memberId() != null && memberIds.contains(row.memberId())))
        .toList();
    }
    rows = rows.stream()
      .filter(row -> !filter.exhaustedOnly() || row.exhausted())
      .filter(row -> !filter.overageOnly() || row.overage() > 0)
      .filter(row -> !filter.frozenOnly() || row.frozen())
      .sorted(comparator(sort))
      .toList();

    int size = PAGE_SIZE;
    int safePage = Math.max(page, 0);
    int from = Math.min(safePage * size, rows.size());
    int to = Math.min(from + size, rows.size());
    List<AdminCreditWeekRow> pageRows = withMembers(rows.subList(from, to), now);
    return new PageImpl<>(pageRows, PageRequest.of(safePage, size), rows.size());
  }

  private static Comparator<AdminCreditWeekRow> comparator(MemberSort sort) {
    // 같은 값이면 계정 id 로 — 페이지를 넘길 때 줄이 뒤섞이지 않게 순서를 고정한다.
    Comparator<AdminCreditWeekRow> tie = Comparator.comparing(AdminCreditWeekRow::accountId);
    return switch (sort) {
      case USED_DESC -> Comparator.comparingLong(AdminCreditWeekRow::used).reversed().thenComparing(tie);
      case OVERAGE_DESC -> Comparator.comparingLong(AdminCreditWeekRow::overage).reversed().thenComparing(tie);
      case REMAINING_ASC -> Comparator.comparingLong(AdminCreditWeekRow::remaining).thenComparing(tie);
    };
  }

  /// 페이지에 실린 줄에만 회원 아이디·호칭·플랜을 붙인다(쿼리 셋).
  private List<AdminCreditWeekRow> withMembers(List<AdminCreditWeekRow> rows, LocalDateTime now) {
    List<String> memberIds = rows.stream().map(AdminCreditWeekRow::memberId).filter(id -> id != null).toList();
    if (memberIds.isEmpty()) {
      return rows;
    }
    Map<String, String> usernames = memberRepository.findAllById(memberIds).stream()
      .collect(Collectors.toMap(Member::getId, Member::getUsername, (a, b) -> a));
    Map<String, String> nicknames = nicknames(memberIds);
    Set<String> pro = new HashSet<>(subscriptionRepository.findMemberIdsWithEffectivePlan(
      PlanType.PRO, SubscriptionStatus.ACTIVE, now));
    return rows.stream()
      .map(row -> row.memberId() == null ? row : row.withMember(
        usernames.get(row.memberId()), nicknames.get(row.memberId()),
        pro.contains(row.memberId()) ? PlanType.PRO : PlanType.FREE))
      .toList();
  }

  private Map<String, String> nicknames(Collection<String> memberIds) {
    Map<String, String> nicknames = new HashMap<>();
    // 이룸이가 여럿이면 가장 먼저 합류한 이룸이(회원 목록과 같은 규칙).
    for (ProfileGuardian guardian : profileGuardianRepository.findAllWithProfileByMemberIdIn(memberIds)) {
      nicknames.putIfAbsent(guardian.getMember().getId(), guardian.getProfile().getNickname());
    }
    return nicknames;
  }

  /**
   * 한 주의 계정별 요약. 그 주에 지급·사용·보너스·초과가 있었거나 동결된 계정만 줄이 된다.
   *
   * <p>이번 주면 남음 = 지금 사용 가능량(주간 남음 + 유효 보너스 − 예약). 지난 주면 주간 지급이 주 말에 남긴 양
   * (남음 + 만료)이다 — 지난 주 묶음은 다음 요청 때 EXPIRE 로 0 이 되므로 남음만 보면 늘 0 이다.
   */
  List<AdminCreditWeekRow> weekRows(CreditPeriod period, LocalDateTime now) {
    boolean current = period.contains(now);
    Map<String, AiCreditGrant> weekly = new HashMap<>();
    for (AiCreditGrant grant : grantRepository.findByPeriodKey(period.key())) {
      if (grant.getSource() == CreditGrantSource.WEEKLY) {
        weekly.put(grant.getAccountId(), grant);
      }
    }
    Map<String, Long> expired = totals(ledgerRepository.sumDeltaOfPeriodGrantsByAccount(
      CreditLedgerType.EXPIRE, period.key()));
    Map<String, Long> consumed = totals(ledgerRepository.sumDeltaByAccount(
      CreditLedgerType.CONSUME, period.start(), period.end()));
    Map<String, Long> bonus = totals(grantRepository.sumNonWeeklyGrantedByAccount(
      CreditGrantSource.WEEKLY, period.start(), period.end()));
    Map<String, Long> reserved = current
      ? totals(jobRepository.sumReservedByAccount(CreditJobStatus.RESERVED)) : Map.of();
    Map<String, Long> validBonus = current
      ? totals(grantRepository.sumValidNonWeeklyRemainingByAccount(CreditGrantSource.WEEKLY, now)) : Map.of();
    Map<String, AccountOverage> overage = jobRepository.sumOverageByAccount(period.start(), period.end()).stream()
      .collect(Collectors.toMap(AccountOverage::getAccountId, Function.identity(), (a, b) -> a));
    Map<String, LocalDateTime> lastUsed = new HashMap<>();
    for (AccountLastAt last : ledgerRepository.lastAtByAccount(CreditLedgerType.CONSUME)) {
      lastUsed.put(last.getAccountId(), last.getLastAt());
    }
    Map<String, AiCreditAccount> accounts = accountRepository.findAll().stream()
      .collect(Collectors.toMap(AiCreditAccount::getId, Function.identity(), (a, b) -> a));

    Set<String> ids = new LinkedHashSet<>(weekly.keySet());
    ids.addAll(consumed.keySet());
    ids.addAll(bonus.keySet());
    ids.addAll(overage.keySet());
    ids.addAll(reserved.keySet());
    accounts.values().stream().filter(AiCreditAccount::isFrozen).forEach(a -> ids.add(a.getId()));

    List<AdminCreditWeekRow> rows = new ArrayList<>();
    for (String id : ids) {
      AiCreditAccount account = accounts.get(id);
      AiCreditGrant grant = weekly.get(id);
      long weeklyLeft = grant == null ? 0 : grant.getRemaining() - expired.getOrDefault(id, 0L);
      long held = reserved.getOrDefault(id, 0L);
      long remaining = current
        ? Math.max(0, weeklyLeft + validBonus.getOrDefault(id, 0L) - held)
        : weeklyLeft;
      AccountOverage over = overage.get(id);
      rows.add(new AdminCreditWeekRow(
        id,
        account == null ? null : account.getMemberId(),
        null,
        null,
        null,
        account != null && account.getStatus() == CreditAccountStatus.FROZEN,
        grant == null ? null : grant.getAmount(),
        bonus.getOrDefault(id, 0L),
        -consumed.getOrDefault(id, 0L),
        held,
        remaining,
        over == null ? 0 : over.getTotal(),
        over == null ? 0 : over.getJobCount(),
        lastUsed.get(id)
      ));
    }
    return rows;
  }

  private static Map<String, Long> totals(List<AccountTotal> totals) {
    Map<String, Long> map = new HashMap<>();
    for (AccountTotal total : totals) {
      map.merge(total.getAccountId(), total.getTotal(), Long::sum);
    }
    return map;
  }

  // --- 회원 상세 ---

  public AdminCreditMemberDetail memberDetail(String memberId, int jobPage, CreditLedgerType ledgerType, int ledgerPage) {
    Member member = memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));
    LocalDateTime now = LocalDateTime.now(clock);
    AiCreditPolicy policy = policyService.current();
    AiCreditAccount account = accountRepository.findByMemberId(memberId).orElse(null);
    String nickname = nicknames(List.of(memberId)).get(memberId);
    PlanType plan = entitlementService.planOf(memberId);

    if (account == null) {
      return new AdminCreditMemberDetail(memberId, member.getUsername(), nickname, plan, null, null, List.of(),
        Page.empty(PageRequest.of(0, PAGE_SIZE)), Page.empty(PageRequest.of(0, PAGE_SIZE)), ledgerType, policy);
    }
    Pageable jobs = PageRequest.of(Math.max(jobPage, 0), PAGE_SIZE);
    Pageable lines = PageRequest.of(Math.max(ledgerPage, 0), PAGE_SIZE);
    Page<AiCreditLedger> ledger = ledgerType == null
      ? ledgerRepository.findByAccountIdOrderByCreatedAtDesc(account.getId(), lines)
      : ledgerRepository.findByAccountIdAndTypeOrderByCreatedAtDesc(account.getId(), ledgerType, lines);
    Page<AdminCreditJobRow> jobRows = jobRows(
      jobRepository.findByAccountIdOrderByStartedAtDesc(account.getId(), jobs), policy, now);
    return new AdminCreditMemberDetail(memberId, member.getUsername(), nickname, plan, account,
      accountService.balance(account, now), accountService.spendableGrants(account.getId(), now),
      jobRows, ledger, ledgerType, policy);
  }

  // --- 작업 탐색 ---

  /**
   * 작업 탐색 필터.
   *
   * @param from 시작일(포함), to 끝날(포함) — started_at 기준
   * @param query request_key 일부 또는 작업 id 그대로
   */
  public record JobFilter(
    CreditJobStatus status, CreditJobKind kind, LocalDate from, LocalDate to,
    boolean overageOnly, boolean mismatchOnly, String query
  ) {

  }

  public Page<AdminCreditJobRow> jobs(JobFilter filter, int page) {
    LocalDateTime now = LocalDateTime.now(clock);
    Pageable pageable = PageRequest.of(Math.max(page, 0), PAGE_SIZE, Sort.by(Sort.Direction.DESC, "startedAt"));
    Page<AiCreditJob> jobs = jobRepository.findAll(specOf(filter), pageable);
    return jobRows(jobs, policyService.current(), now);
  }

  /// 필터를 조건으로 바꾼다. 조건마다 JPQL 을 따로 두지 않으려고 Criteria 로 붙인다.
  static Specification<AiCreditJob> specOf(JobFilter filter) {
    return (root, query, cb) -> {
      List<Predicate> predicates = new ArrayList<>();
      if (filter.status() != null) {
        predicates.add(cb.equal(root.get("status"), filter.status()));
      }
      if (filter.kind() != null) {
        predicates.add(cb.equal(root.get("kind"), filter.kind()));
      }
      if (filter.from() != null) {
        predicates.add(cb.greaterThanOrEqualTo(root.get("startedAt"), filter.from().atStartOfDay()));
      }
      if (filter.to() != null) {
        predicates.add(cb.lessThan(root.get("startedAt"), filter.to().plusDays(1).atStartOfDay()));
      }
      if (filter.overageOnly()) {
        predicates.add(cb.greaterThan(root.get("overage"), 0));
      }
      if (filter.mismatchOnly()) {
        // 청구가 있었는데 연결된 호출 기록이 없는 정산 작업 — 개요 경고와 같은 조건.
        Subquery<String> calls = query.subquery(String.class);
        var log = calls.from(AiCallLog.class);
        calls.select(log.get("id")).where(cb.equal(log.get("creditJobId"), root.get("id")));
        predicates.add(cb.equal(root.get("status"), CreditJobStatus.SETTLED));
        predicates.add(cb.greaterThan(cb.sum(root.get("charged"), root.get("overage")), 0));
        predicates.add(cb.not(cb.exists(calls)));
      }
      String q = filter.query() == null ? "" : filter.query().trim();
      if (!q.isEmpty()) {
        predicates.add(cb.or(
          cb.equal(root.get("id"), q),
          cb.like(cb.lower(root.get("requestKey")), "%" + q.toLowerCase() + "%")));
      }
      return cb.and(predicates.toArray(Predicate[]::new));
    };
  }

  /// 작업 한 페이지에 연결 호출 대조·회원 아이디를 붙인다(쿼리 셋 — 줄마다 묻지 않는다).
  private Page<AdminCreditJobRow> jobRows(Page<AiCreditJob> jobs, AiCreditPolicy policy, LocalDateTime now) {
    List<String> jobIds = jobs.getContent().stream().map(AiCreditJob::getId).toList();
    Map<String, CreditJobCost> costs = jobIds.isEmpty() ? Map.of()
      : aiCallLogRepository.sumCostByCreditJobIds(jobIds).stream()
        .collect(Collectors.toMap(CreditJobCost::getCreditJobId, Function.identity(), (a, b) -> a));
    Set<String> accountIds = jobs.getContent().stream().map(AiCreditJob::getAccountId).collect(Collectors.toSet());
    Map<String, String> memberByAccount = new HashMap<>();
    if (!accountIds.isEmpty()) {
      for (AiCreditAccount account : accountRepository.findAllById(accountIds)) {
        if (account.getMemberId() != null) {
          memberByAccount.put(account.getId(), account.getMemberId());
        }
      }
    }
    Map<String, String> usernames = memberByAccount.isEmpty() ? Map.of()
      : memberRepository.findAllById(new HashSet<>(memberByAccount.values())).stream()
        .collect(Collectors.toMap(Member::getId, Member::getUsername, (a, b) -> a));
    LocalDateTime threshold = stuckThreshold(policy, now);
    return jobs.map(job -> {
      CreditJobCost cost = costs.get(job.getId());
      String memberId = memberByAccount.get(job.getAccountId());
      boolean stuck = job.getStatus() == CreditJobStatus.RESERVED
        && job.getStartedAt() != null && job.getStartedAt().isBefore(threshold);
      return new AdminCreditJobRow(job, memberId, memberId == null ? null : usernames.get(memberId),
        cost == null ? 0 : cost.getCallCount(), cost == null ? 0 : cost.getTotalCostUsd(), stuck);
    });
  }

  /// 멈춘 예약 기준 — 지금 정책의 예약 유지 시간보다 오래 RESERVED 인 작업.
  static LocalDateTime stuckThreshold(AiCreditPolicy policy, LocalDateTime now) {
    return now.minusMinutes(policy.getReservationTtlMinutes());
  }

  /// 비용 상한 도달 여부. 집계 실패는 가드가 false 로 돌려준다 — 경고 하나 때문에 개요가 깨지지 않게 여기서도 감싼다.
  private boolean budgetReached() {
    try {
      return dailyBudgetGuard.isReached();
    } catch (RuntimeException e) {
      log.warn("관리자 크레딧 개요 — 비용 상한 확인 실패, 경고를 띄우지 않는다", e);
      return false;
    }
  }
}
