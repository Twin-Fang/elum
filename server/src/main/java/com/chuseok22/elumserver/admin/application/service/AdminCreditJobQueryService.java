package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditJobRow;
import com.chuseok22.elumserver.admin.application.list.AdminListDefaults;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.CreditJobCost;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.credit.application.service.CreditPolicyService;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditJobStatus;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import jakarta.persistence.criteria.Predicate;
import jakarta.persistence.criteria.Subquery;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 관리자 크레딧 작업 탐색: 필터 조건 조립, 작업 한 페이지에 호출 비용·회원 붙이기, 멈춘 예약 기준
 * 읽기만 함 (줄마다 묻지 않고 쿼리 셋으로 대조)
 */
@Slf4j
@Service
@Transactional(readOnly = true)
public class AdminCreditJobQueryService {

  private final CreditPolicyService policyService;
  private final AiCreditAccountRepository accountRepository;
  private final AiCreditJobRepository jobRepository;
  private final AiCallLogRepository aiCallLogRepository;
  private final MemberRepository memberRepository;
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 빠뜨리면 서버가 뜨지 않는다.
  @Autowired
  public AdminCreditJobQueryService(
    CreditPolicyService policyService, AiCreditAccountRepository accountRepository,
    AiCreditJobRepository jobRepository, AiCallLogRepository aiCallLogRepository,
    MemberRepository memberRepository
  ) {
    this(policyService, accountRepository, jobRepository, aiCallLogRepository, memberRepository,
      Clock.systemDefaultZone());
  }

  AdminCreditJobQueryService(
    CreditPolicyService policyService, AiCreditAccountRepository accountRepository,
    AiCreditJobRepository jobRepository, AiCallLogRepository aiCallLogRepository,
    MemberRepository memberRepository, Clock clock
  ) {
    this.policyService = policyService;
    this.accountRepository = accountRepository;
    this.jobRepository = jobRepository;
    this.aiCallLogRepository = aiCallLogRepository;
    this.memberRepository = memberRepository;
    this.clock = clock;
  }

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
    Pageable pageable = PageRequest.of(Math.max(page, 0), AdminListDefaults.PAGE_SIZE, Sort.by(Sort.Direction.DESC, "startedAt"));
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
  Page<AdminCreditJobRow> jobRows(Page<AiCreditJob> jobs, AiCreditPolicy policy, LocalDateTime now) {
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
}
