package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.request.CreditAdjustForm;
import com.chuseok22.elumserver.admin.application.dto.request.CreditAdjustType;
import com.chuseok22.elumserver.admin.application.dto.response.CreditAdjustPreview;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.application.service.CreditBalance;
import com.chuseok22.elumserver.credit.application.service.CreditPolicyService;
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
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 관리자 크레딧 쓰기 — 조정·수동 반환. 정책 발행과 미리보기는 AdminCreditPolicyService.
 *
 * <p>모든 쓰기는 계정 행을 잠근 안에서 하고 원장에 관리자 아이디(actor)와 사유를 남긴다. 미리보기와 반영은 같은
 * 잔액 계산({@link CreditAccountService#balance})을 거쳐 "미리보기에서 본 숫자 = 반영 뒤 숫자"가 된다.
 *
 * <p>폼 입력이 틀리면 {@link CustomException}(ADMIN_CREDIT_* 코드)을 던진다. 컨트롤러가 폼 오류로
 * 바꾼다 — 500 으로 떨어지지 않게.
 */
@Slf4j
@Service
public class AdminCreditService {

  /// 한 번에 지급·차감할 수 있는 상한. 0 을 하나 더 친 실수를 막는다.
  static final int MAX_ADJUST_AMOUNT = 10_000;

  private final CreditPolicyService policyService;
  private final CreditAccountService accountService;
  private final AiCreditAccountRepository accountRepository;
  private final AiCreditGrantRepository grantRepository;
  private final AiCreditJobRepository jobRepository;
  private final AiCreditLedgerRepository ledgerRepository;
  private final MemberRepository memberRepository;
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 빠뜨리면 서버가 뜨지 않는다.
  @Autowired
  public AdminCreditService(
    CreditPolicyService policyService, CreditAccountService accountService,
    AiCreditAccountRepository accountRepository, AiCreditGrantRepository grantRepository,
    AiCreditJobRepository jobRepository, AiCreditLedgerRepository ledgerRepository,
    MemberRepository memberRepository
  ) {
    this(policyService, accountService, accountRepository, grantRepository, jobRepository, ledgerRepository,
      memberRepository, Clock.systemDefaultZone());
  }

  AdminCreditService(
    CreditPolicyService policyService, CreditAccountService accountService,
    AiCreditAccountRepository accountRepository, AiCreditGrantRepository grantRepository,
    AiCreditJobRepository jobRepository, AiCreditLedgerRepository ledgerRepository,
    MemberRepository memberRepository, Clock clock
  ) {
    this.policyService = policyService;
    this.accountService = accountService;
    this.accountRepository = accountRepository;
    this.grantRepository = grantRepository;
    this.jobRepository = jobRepository;
    this.ledgerRepository = ledgerRepository;
    this.memberRepository = memberRepository;
    this.clock = clock;
  }

  // --- 조정 ---

  /**
   * 조정 결과를 미리 계산한다. 아무것도 쓰지 않는다(계정이 없으면 잔액 0 으로 본다).
   *
   * @throws CustomException 수량·만료·차감 상한·동결 상태가 맞지 않을 때 (ADMIN_CREDIT_*)
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
   * @throws CustomException 사유가 비었거나 미리보기와 같은 검사에 걸릴 때 (ADMIN_CREDIT_*)
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
        AiCreditLedger line = AdminCreditLedgerLine.of(account.getId(), CreditLedgerType.ADJUST, amount,
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
          AiCreditLedger line = AdminCreditLedgerLine.of(account.getId(), CreditLedgerType.ADJUST, -take, running, actor, ledgerReason);
          line.setGrantId(grant.getId());
          line.setPolicyVersion(policyVersion);
          ledgerRepository.save(line);
        }
      }
      case FREEZE, UNFREEZE -> {
        account.setStatus(type == CreditAdjustType.FREEZE ? CreditAccountStatus.FROZEN : CreditAccountStatus.ACTIVE);
        accountRepository.save(account);
        // 잔액은 그대로지만 누가 왜 막았는지는 원장에 남아야 한다.
        AiCreditLedger line = AdminCreditLedgerLine.of(account.getId(), CreditLedgerType.ADJUST, 0, before.available(), actor,
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
   * @throws CustomException 날짜를 고르고 비웠거나 형식이 틀릴 때 (ADMIN_CREDIT_EXPIRY_DATE_*)
   */
  public LocalDateTime resolveExpiry(String mode, String date) {
    String chosen = (mode == null || mode.isBlank()) ? CreditAdjustForm.EXPIRY_WEEK_END : mode.trim();
    return switch (chosen) {
      case CreditAdjustForm.EXPIRY_NONE -> null;
      case CreditAdjustForm.EXPIRY_DATE -> {
        if (date == null || date.isBlank()) {
          throw new CustomException(ErrorCode.ADMIN_CREDIT_EXPIRY_DATE_REQUIRED);
        }
        try {
          yield LocalDate.parse(date.trim()).plusDays(1).atStartOfDay();
        } catch (DateTimeParseException e) {
          throw new CustomException(ErrorCode.ADMIN_CREDIT_EXPIRY_DATE_INVALID, date);
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
      throw new CustomException(ErrorCode.ADMIN_CREDIT_REASON_REQUIRED);
    }
    String trimmed = reason.trim();
    if (trimmed.length() > CreditPolicyService.ADMIN_REASON_MAX_LENGTH) {
      throw new CustomException(ErrorCode.ADMIN_CREDIT_REASON_TOO_LONG,
        CreditPolicyService.ADMIN_REASON_MAX_LENGTH + "자까지");
    }
    return trimmed;
  }

  private CreditAdjustPreview preview(
    CreditAdjustType type, int amount, LocalDateTime expiresAt, int available, boolean frozen, LocalDateTime now
  ) {
    if (type == null) {
      throw new CustomException(ErrorCode.ADMIN_CREDIT_ADJUST_TYPE_REQUIRED);
    }
    if (type.hasAmount()) {
      if (amount < 1) {
        throw new CustomException(ErrorCode.ADMIN_CREDIT_AMOUNT_TOO_SMALL);
      }
      if (amount > MAX_ADJUST_AMOUNT) {
        throw new CustomException(ErrorCode.ADMIN_CREDIT_AMOUNT_TOO_LARGE, "최대 " + MAX_ADJUST_AMOUNT);
      }
    }
    return switch (type) {
      case GRANT -> {
        if (expiresAt != null && !expiresAt.isAfter(now)) {
          throw new CustomException(ErrorCode.ADMIN_CREDIT_EXPIRY_NOT_FUTURE);
        }
        yield new CreditAdjustPreview(type, amount, available, available + amount, expiresAt, frozen, frozen);
      }
      case DEDUCT -> {
        // 예약 중인 몫은 뺄 수 없다 — 빼면 정산 때 차감할 묶음이 모자라 초과로 샌다.
        if (amount > available) {
          throw new CustomException(ErrorCode.ADMIN_CREDIT_DEDUCT_EXCEEDS_AVAILABLE, "남은 크레딧 " + available);
        }
        yield new CreditAdjustPreview(type, amount, available, available - amount, null, frozen, frozen);
      }
      case FREEZE -> {
        if (frozen) {
          throw new CustomException(ErrorCode.ADMIN_CREDIT_ACCOUNT_ALREADY_FROZEN);
        }
        yield new CreditAdjustPreview(type, 0, available, available, null, false, true);
      }
      case UNFREEZE -> {
        if (!frozen) {
          throw new CustomException(ErrorCode.ADMIN_CREDIT_ACCOUNT_NOT_FROZEN);
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
   * @throws CustomException 사유가 없거나 작업이 없거나 이미 끝났을 때 (ADMIN_CREDIT_*)
   */
  @Transactional
  public String manualRelease(String jobId, String actor, String reason) {
    String cleanReason = requireReason(reason);
    // 계정을 잠근 뒤에 작업을 읽는다 — 먼저 읽으면 그 사이 정산된 것을 못 본다.
    String accountId = jobRepository.findAccountIdById(jobId)
      .orElseThrow(() -> new CustomException(ErrorCode.ADMIN_CREDIT_JOB_NOT_FOUND, jobId));
    AiCreditAccount account = accountService.lockAccountById(accountId);
    AiCreditJob job = jobRepository.findById(jobId)
      .orElseThrow(() -> new CustomException(ErrorCode.ADMIN_CREDIT_JOB_NOT_FOUND, jobId));
    if (job.getStatus() != CreditJobStatus.RESERVED) {
      throw new CustomException(ErrorCode.ADMIN_CREDIT_JOB_NOT_RELEASABLE, "지금 상태 " + job.getStatus().name());
    }
    LocalDateTime now = LocalDateTime.now(clock);
    int balanceAfter = accountService.balance(account, now).available() + job.getReserved();
    job.setStatus(CreditJobStatus.RELEASED);
    job.setFinishedAt(now);
    job.setFailReason("관리자 반환: " + cleanReason);
    jobRepository.save(job);

    AiCreditLedger line = AdminCreditLedgerLine.of(accountId, CreditLedgerType.RELEASE, job.getReserved(), balanceAfter, actor,
      "[관리자 반환] " + cleanReason);
    line.setJobId(jobId);
    line.setPolicyVersion(job.getPolicyVersion());
    ledgerRepository.save(line);
    log.info("관리자 크레딧 예약 수동 반환: jobId={}, accountId={}, actor={}", jobId, accountId, actor);
    return account.getMemberId();
  }

  // --- 공통 ---

  private void requireMember(String memberId) {
    if (memberId == null || !memberRepository.existsById(memberId)) {
      throw new CustomException(ErrorCode.MEMBER_NOT_FOUND);
    }
  }

  private Integer currentPolicyVersion() {
    AiCreditPolicy policy = policyService.current();
    return policy.getVersion() > 0 ? policy.getVersion() : null;
  }
}
