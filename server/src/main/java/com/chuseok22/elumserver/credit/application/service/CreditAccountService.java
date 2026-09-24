package com.chuseok22.elumserver.credit.application.service;

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
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.core.PlanType;
import jakarta.persistence.EntityManager;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.List;
import java.util.Optional;
import java.util.function.Function;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * 크레딧 계정·적립 묶음·잔액 (#407).
 *
 * <p>잠금·지급·만료는 호출자 트랜잭션 안에서만 뜻이 있다(MANDATORY) — 잠근 채로 이어서 예약·정산해야
 * 그 사이 다른 요청이 끼지 않는다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CreditAccountService {

  static final String SYSTEM_ACTOR = "system";

  /// 무기한 묶음을 차감 순서 맨 뒤로 보내는 정렬 기준.
  private static final Comparator<AiCreditGrant> EXPIRING_FIRST = Comparator.comparing(
    AiCreditGrant::getExpiresAt, Comparator.nullsLast(Comparator.naturalOrder()));

  private final AiCreditAccountRepository accountRepository;
  private final AiCreditGrantRepository grantRepository;
  private final AiCreditJobRepository jobRepository;
  private final AiCreditLedgerRepository ledgerRepository;
  /// 잠근 뒤 행을 다시 읽는 데만 쓴다(lockAccountById).
  private final EntityManager entityManager;

  /**
   * 회원의 계정을 잠가 돌려준다. 없으면 만든 뒤 잠근다.
   *
   * <p>V26 이 기존 회원 계정을 미리 만들고 가입 때 {@link #linkIdentity} 가 만들므로, 여기서 만드는 경우는
   * 드물다(빠진 회원). 같은 회원의 첫 요청 둘이 동시에 만들면 한쪽이 유니크 제약에 걸려 장부 오류(503)가
   * 되고, 다시 하면 이미 만든 계정을 잠근다.
   */
  @Transactional(propagation = Propagation.MANDATORY)
  public AiCreditAccount lockAccount(String memberId) {
    // 처음 읽기부터 잠근다. 잠그지 않고 먼저 읽으면 그 인스턴스가 1차 캐시에 남아, 잠금 조회가 잠그기 전
    // 상태(예: 그 사이 관리자가 동결)를 돌려준다.
    Optional<AiCreditAccount> locked = accountRepository.findByMemberIdForUpdate(memberId);
    if (locked.isPresent()) {
      return refreshed(locked.get());
    }
    AiCreditAccount created = new AiCreditAccount();
    created.setMemberId(memberId);
    log.info("크레딧 계정 생성(첫 요청): memberId={}", memberId);
    return lockAccountById(accountRepository.save(created).getId());
  }

  /**
   * 계정 행을 잠가 돌려준다. 잠근 뒤 행을 다시 읽는다 — 같은 트랜잭션에서 잠그기 전에 이 계정을 읽었다면
   * 잠금 조회는 1차 캐시의 옛 인스턴스를 그대로 돌려주기 때문이다.
   *
   * <p>계정 필드(상태 등)는 잠근 <b>뒤에</b> 바꾼다. 바꾼 뒤 저장(flush) 전에 다시 잠그면 다시 읽기가 그 변경을 덮는다.
   */
  @Transactional(propagation = Propagation.MANDATORY)
  public AiCreditAccount lockAccountById(String accountId) {
    AiCreditAccount account = accountRepository.findByIdForUpdate(accountId)
      .orElseThrow(() -> {
        log.error("크레딧 계정을 잠그지 못했다 — 행이 없다: accountId={}", accountId);
        return new CustomException(ErrorCode.AI_CREDIT_UNAVAILABLE);
      });
    return refreshed(account);
  }

  /// 행 잠금을 쥔 채로 DB 의 지금 상태로 덮는다. 잠금 안이라 읽은 뒤 바뀌지 않는다.
  private AiCreditAccount refreshed(AiCreditAccount account) {
    entityManager.refresh(account);
    return account;
  }

  /// 잠그지 않고 읽는다. 멱등 재요청처럼 "이미 끝난 작업이 있나"만 볼 때 쓴다 — 쓰기 트랜잭션 밖에서 부른다.
  @Transactional(readOnly = true)
  public Optional<AiCreditAccount> findAccount(String memberId) {
    return accountRepository.findByMemberId(memberId);
  }

  /**
   * 이번 주 주간 지급을 보장한다. 기한이 지난 묶음의 남은 양은 먼저 EXPIRE 로 정리한다(이월 없음).
   *
   * <p>배치 없이 그 주 첫 조회·요청 때 만든다 — 한 주 동안 안 쓰는 회원에게는 행을 만들지 않는다.
   * 계정 잠금 안이라 같은 주 두 번 만들 경쟁이 없고, (account_id, period_key) 유니크가 마지막 안전판이다.
   */
  @Transactional(propagation = Propagation.MANDATORY)
  public void ensureWeeklyGrant(AiCreditAccount account, AiCreditPolicy policy, PlanType plan, LocalDateTime now) {
    ensureWeeklyGrant(account, period -> policy, plan, now);
  }

  /**
   * 지급량을 정할 정책을 주기로 고른다({@link CreditPolicyService#grantPolicyFor}). 지급 행이 이미 있으면
   * 고르지 않는다 — 대부분의 요청이 여기서 끝나 정책 조회가 더 들지 않는다.
   */
  @Transactional(propagation = Propagation.MANDATORY)
  public void ensureWeeklyGrant(
    AiCreditAccount account, Function<CreditPeriod, AiCreditPolicy> grantPolicyOf, PlanType plan, LocalDateTime now
  ) {
    CreditPeriod period = CreditPeriod.of(now);
    expireEndedGrants(account, period, now);

    if (grantRepository.findByAccountIdAndPeriodKey(account.getId(), period.key()).isPresent()) {
      return;
    }
    AiCreditPolicy policy = grantPolicyOf.apply(period);
    int amount = policy.weeklyGrantFor(plan);
    AiCreditGrant grant = new AiCreditGrant();
    grant.setAccountId(account.getId());
    grant.setSource(CreditGrantSource.WEEKLY);
    grant.setAmount(amount);
    grant.setRemaining(amount);
    grant.setValidFrom(period.start());
    grant.setExpiresAt(period.end());
    grant.setPeriodKey(period.key());
    grant.setPolicyVersion(policy.getVersion());
    // 지급량이 0 이어도 행은 만든다 — 없으면 이번 주 요청마다 지급을 다시 시도한다.
    int balanceBefore = balance(account, now).available();
    AiCreditGrant saved = grantRepository.save(grant);

    AiCreditLedger line = ledgerLine(account.getId(), CreditLedgerType.GRANT, amount, balanceBefore + amount);
    line.setGrantId(saved.getId());
    line.setPolicyVersion(policy.getVersion());
    line.setReason("주간 지급 " + period.key() + " (" + plan.name() + ")");
    ledgerRepository.save(line);
  }

  /** 기한이 지났거나 지난 주기의 주간 묶음에 남은 양을 0 으로 만들고 EXPIRE 를 남긴다. */
  private void expireEndedGrants(AiCreditAccount account, CreditPeriod period, LocalDateTime now) {
    List<AiCreditGrant> ended = grantRepository.findByAccountIdAndRemainingGreaterThan(account.getId(), 0).stream()
      .filter(grant -> isEnded(grant, period, now))
      .toList();
    if (ended.isEmpty()) {
      return;
    }
    int running = balance(account, now).available();
    for (AiCreditGrant grant : ended) {
      int expired = grant.getRemaining();
      grant.setRemaining(0);
      // 기한이 지난 묶음은 이미 잔액 계산에서 빠져 있다 — 사용 가능량은 그대로이고 원장만 맞춘다.
      if (grant.isValidAt(now)) {
        running = Math.max(0, running - expired);
      }
      AiCreditLedger line = ledgerLine(account.getId(), CreditLedgerType.EXPIRE, -expired, running);
      line.setGrantId(grant.getId());
      line.setReason("기한 만료 " + (grant.getPeriodKey() != null ? grant.getPeriodKey() : grant.getSource().name()));
      ledgerRepository.save(line);
    }
  }

  private static boolean isEnded(AiCreditGrant grant, CreditPeriod period, LocalDateTime now) {
    boolean expired = grant.getExpiresAt() != null && !now.isBefore(grant.getExpiresAt());
    boolean pastWeekly = grant.getSource() == CreditGrantSource.WEEKLY && !period.key().equals(grant.getPeriodKey());
    return expired || pastWeekly;
  }

  /**
   * 지금 잔액. 읽기만 한다 — 주간 지급·만료 정리는 {@link #ensureWeeklyGrant} 가 한다.
   *
   * <p>트랜잭션을 따로 걸지 않는다. 예약·정산의 쓰기 트랜잭션 안에서 불려 방금 바꾼 묶음을 그대로 봐야 한다.
   */
  public CreditBalance balance(AiCreditAccount account, LocalDateTime now) {
    CreditPeriod period = CreditPeriod.of(now);
    List<AiCreditGrant> valid = spendableGrants(account.getId(), now);
    int remaining = valid.stream().mapToInt(AiCreditGrant::getRemaining).sum();
    int bonus = valid.stream()
      .filter(grant -> grant.getSource() != CreditGrantSource.WEEKLY)
      .mapToInt(AiCreditGrant::getRemaining)
      .sum();
    int reserved = jobRepository.findByAccountIdAndStatus(account.getId(), CreditJobStatus.RESERVED).stream()
      .mapToInt(AiCreditJob::getReserved)
      .sum();
    int weeklyGrant = grantRepository.findByAccountIdAndPeriodKey(account.getId(), period.key())
      .map(AiCreditGrant::getAmount)
      .orElse(0);
    // CONSUME 은 음수로 쌓인다.
    long consumed = ledgerRepository.sumDelta(account.getId(), CreditLedgerType.CONSUME, period.start(), period.end());
    return new CreditBalance(Math.max(0, remaining - reserved), weeklyGrant, bonus, (int) -consumed, reserved, period);
  }

  /** 지금 쓸 수 있는 묶음, 차감 순서대로 — 만료 임박부터, 무기한은 마지막. */
  public List<AiCreditGrant> spendableGrants(String accountId, LocalDateTime now) {
    return grantRepository.findByAccountIdAndRemainingGreaterThan(accountId, 0).stream()
      .filter(grant -> grant.isValidAt(now))
      .sorted(EXPIRING_FIRST)
      .toList();
  }

  /**
   * 소셜 신원으로 계정을 잇는다. 재가입(완전 삭제 뒤 같은 소셜 계정)이면 떼어 둔 계정을 새 회원에 다시 붙인다.
   *
   * <p>로그인 트랜잭션과 떼어 둔다(REQUIRES_NEW) — 여기서 실패해도 로그인이 롤백 전용으로 물들지 않게.
   * 호출자는 예외를 잡아 로그만 남긴다(크레딧 계정은 첫 요청에서도 만들어진다).
   */
  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public void linkIdentity(String memberId, String identityKey) {
    if (memberId == null || identityKey == null || identityKey.isBlank()) {
      return;
    }
    Optional<AiCreditAccount> byIdentity = accountRepository.findByIdentityKey(identityKey);
    if (byIdentity.isPresent()) {
      AiCreditAccount account = byIdentity.get();
      if (account.getMemberId() == null) {
        if (accountRepository.findByMemberId(memberId).isPresent()) {
          // 이 회원이 이미 첫 요청으로 새 계정을 받았다. 둘을 합치는 일은 관리자 판단으로 남긴다.
          log.warn("재가입 계정 재연결 보류 — 회원에게 이미 계정이 있다: memberId={}, accountId={}",
            memberId, account.getId());
          return;
        }
        account.setMemberId(memberId);
        accountRepository.save(account);
        log.info("재가입 회원에 크레딧 계정을 다시 붙였다: memberId={}, accountId={}", memberId, account.getId());
      } else if (!account.getMemberId().equals(memberId)) {
        // 한 소셜 신원은 한 회원에게만 있다. 여기 오면 데이터가 어긋난 것이라 빼앗지 않고 남긴다.
        log.warn("다른 회원이 쓰는 신원 키 — 연결하지 않는다: memberId={}, accountId={}", memberId, account.getId());
      }
      return;
    }

    AiCreditAccount account = accountRepository.findByMemberId(memberId).orElseGet(AiCreditAccount::new);
    if (account.getIdentityKey() != null) {
      // 먼저 연결한 신원이 있다(두 번째 소셜 연결). 첫 신원을 기준으로 둔다.
      return;
    }
    account.setMemberId(memberId);
    account.setIdentityKey(identityKey);
    accountRepository.save(account);
  }

  /** 완전 삭제 때 회원 식별자만 뗀다. 행·원장은 남아 재가입 때 이어 붙는다. */
  @Transactional
  public void detachMember(String memberId) {
    accountRepository.detachMember(memberId);
  }

  /// sha256("{provider}:{providerUserId}") hex. V26 의 encode(sha256(convert_to(provider||':'||id,'UTF8')),'hex') 와 같다.
  public static String identityKey(String provider, String providerUserId) {
    try {
      byte[] digest = MessageDigest.getInstance("SHA-256")
        .digest((provider + ":" + providerUserId).getBytes(StandardCharsets.UTF_8));
      return HexFormat.of().formatHex(digest);
    } catch (NoSuchAlgorithmException e) {
      // 모든 JVM 이 SHA-256 을 갖춘다(자바 표준 필수 알고리즘).
      throw new IllegalStateException(e);
    }
  }

  static AiCreditLedger ledgerLine(String accountId, CreditLedgerType type, int delta, int balanceAfter) {
    AiCreditLedger line = new AiCreditLedger();
    line.setAccountId(accountId);
    line.setType(type);
    line.setDelta(delta);
    line.setBalanceAfter(balanceAfter);
    line.setActor(SYSTEM_ACTOR);
    return line;
  }
}
