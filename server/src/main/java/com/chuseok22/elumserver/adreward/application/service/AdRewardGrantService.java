package com.chuseok22.elumserver.adreward.application.service;

import com.chuseok22.elumserver.adreward.core.AdRewardRejectReason;
import com.chuseok22.elumserver.adreward.core.AdRewardStatus;
import com.chuseok22.elumserver.adreward.infrastructure.entity.AdRewardSession;
import com.chuseok22.elumserver.adreward.infrastructure.repository.AdRewardSessionRepository;
import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.core.CreditPeriod;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 서명이 확인된 Google 콜백으로 크레딧을 준다.
 *
 * <p>**지켜야 하는 것**
 * <ul>
 *   <li>한 번의 시청은 **한 번만** 준다 — 세션 상태·`transaction_id` 유니크·묶음 `ref_id` 세 겹.</li>
 *   <li>세션을 **먼저 잠근 뒤** 계정을 잠근다. 같은 시청의 콜백 둘(Google 재시도)이 동시에 와도 한 줄로 서서 두 번째는
 *       이미 지급된 것을 본다. 서버가 여러 대여도 DB 잠금이 세운다.</li>
 *   <li>**세션을 지급됨으로 바꾸는 것은 맨 마지막이다.** 묶음·원장 저장이 실패하면 트랜잭션이 되돌아가고 세션은
 *       `PENDING` 으로 남아, Google 재시도가 다시 지급할 수 있다.</li>
 *   <li>지급량은 서버 설정이 정한다. Google 이 보낸 `reward_amount` 는 쓰지 않는다.</li>
 * </ul>
 */
@Slf4j
@Service
public class AdRewardGrantService {

  private static final String SYSTEM_ACTOR = "system";

  private final AdRewardSettings settings;
  private final AdRewardSessionRepository sessionRepository;
  private final CreditAccountService accountService;
  private final AiCreditGrantRepository grantRepository;
  private final AiCreditLedgerRepository ledgerRepository;
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 이 앱에는 Clock 빈이 없어 빠뜨리면 서버가 뜨지 않는다.
  @Autowired
  public AdRewardGrantService(
    AdRewardSettings settings, AdRewardSessionRepository sessionRepository, CreditAccountService accountService,
    AiCreditGrantRepository grantRepository, AiCreditLedgerRepository ledgerRepository
  ) {
    this(settings, sessionRepository, accountService, grantRepository, ledgerRepository, Clock.systemDefaultZone());
  }

  AdRewardGrantService(
    AdRewardSettings settings, AdRewardSessionRepository sessionRepository, CreditAccountService accountService,
    AiCreditGrantRepository grantRepository, AiCreditLedgerRepository ledgerRepository, Clock clock
  ) {
    this.settings = settings;
    this.sessionRepository = sessionRepository;
    this.accountService = accountService;
    this.grantRepository = grantRepository;
    this.ledgerRepository = ledgerRepository;
    this.clock = clock;
  }

  @Transactional
  public AdRewardResult grant(SsvCallback callback) {
    AdRewardSession session = sessionRepository.findByNonceForUpdate(callback.customData()).orElse(null);
    if (session == null) {
      // 서명은 맞지만 우리가 만든 세션이 아니다. 조용히 200 으로 답해 Google 이 다시 보내지 않게 한다.
      log.warn("광고 보상 콜백의 세션을 찾지 못했다: nonce={}…", preview(callback.customData()));
      return AdRewardResult.ignored();
    }
    LocalDateTime now = LocalDateTime.now(clock);
    // 세션을 잠근 다음 계정을 잠근다(반대 순서로 잠그는 곳이 없어 교착이 없다).
    AiCreditAccount account = accountService.lockAccount(session.getMemberId());

    if (session.getStatus() == AdRewardStatus.GRANTED) {
      return alreadyGranted(session, callback);
    }
    if (session.getStatus() != AdRewardStatus.PENDING) {
      log.warn("끝난 세션에 콜백이 왔다: sessionId={}, status={}", session.getId(), session.getStatus());
      return AdRewardResult.rejected(AdRewardRejectReason.NOT_PENDING);
    }
    if (sessionRepository.existsByTransactionId(callback.transactionId())) {
      // 같은 시청(transaction_id)을 다른 세션으로 다시 쓰려는 시도다. 지급하지 않고, 이 세션은 PENDING 으로 둔다.
      log.warn("이미 쓰인 transaction_id 다: sessionId={}", session.getId());
      return AdRewardResult.duplicate();
    }
    if (session.isExpiredAt(now)) {
      session.setStatus(AdRewardStatus.EXPIRED);
      session.setRejectReason(AdRewardRejectReason.EXPIRED);
      sessionRepository.save(session);
      return AdRewardResult.rejected(AdRewardRejectReason.EXPIRED);
    }

    AdRewardRejectReason rejection = findRejection(session, callback, account, now);
    if (rejection != null) {
      session.setStatus(AdRewardStatus.REJECTED);
      session.setRejectReason(rejection);
      sessionRepository.save(session);
      log.info("광고 보상을 주지 않았다: sessionId={}, reason={}", session.getId(), rejection);
      return AdRewardResult.rejected(rejection);
    }

    int credits = settings.creditsPerView();
    int before = accountService.balance(account, now).available();
    AiCreditGrant grant = new AiCreditGrant();
    grant.setAccountId(account.getId());
    grant.setSource(CreditGrantSource.AD_REWARD);
    grant.setAmount(credits);
    grant.setRemaining(credits);
    grant.setValidFrom(now);
    // 광고로 받은 크레딧이 무기한으로 쌓이지 않게 이번 주 끝에 사라진다.
    grant.setExpiresAt(CreditPeriod.of(now).end());
    grant.setRefId("ad:" + callback.transactionId());
    AiCreditGrant saved = grantRepository.save(grant);

    AiCreditLedger line = new AiCreditLedger();
    line.setAccountId(account.getId());
    line.setType(CreditLedgerType.GRANT);
    line.setDelta(credits);
    line.setBalanceAfter(before + credits);
    line.setActor(SYSTEM_ACTOR);
    line.setReason("광고 시청 보상");
    line.setGrantId(saved.getId());
    ledgerRepository.save(line);

    // 맨 마지막이다. 위가 실패하면 여기까지 오지 못하고 세션은 PENDING 으로 남는다.
    session.setStatus(AdRewardStatus.GRANTED);
    session.setGrantedAt(now);
    session.setGrantedCredits(credits);
    session.setTransactionId(callback.transactionId());
    session.setGrantId(saved.getId());
    sessionRepository.save(session);
    log.info("광고 보상 지급: memberId={}, sessionId={}, credits={}", session.getMemberId(), session.getId(), credits);
    return AdRewardResult.granted();
  }

  private AdRewardResult alreadyGranted(AdRewardSession session, SsvCallback callback) {
    if (callback.transactionId().equals(session.getTransactionId())) {
      // Google 이 같은 콜백을 다시 보냈다. 이미 준 것에 대한 정상 응답이다.
      return AdRewardResult.duplicate();
    }
    // 이미 지급된 세션에 새 시청이 왔다. 더 주지 않고 세션도 바꾸지 않는다. 앱은 지급 뒤 새 세션을 받아야 한다.
    log.warn("이미 지급된 세션에 새 시청이 왔다: sessionId={}", session.getId());
    return AdRewardResult.rejected(AdRewardRejectReason.NOT_PENDING);
  }

  /// 지급하면 안 되는 사유. 없으면 null. **계정 잠금 안에서 부른다** — 하루 횟수를 이 안에서 세야 동시 요청이 상한을 넘지 못한다.
  private AdRewardRejectReason findRejection(
    AdRewardSession session, SsvCallback callback, AiCreditAccount account, LocalDateTime now
  ) {
    if (!settings.enabled()) {
      return AdRewardRejectReason.DISABLED;
    }
    if (!settings.isAllowedAdUnit(callback.adUnit())) {
      return AdRewardRejectReason.AD_UNIT;
    }
    if (account.isFrozen()) {
      return AdRewardRejectReason.FROZEN;
    }
    long today = grantRepository.countByAccountIdAndSourceAndValidFromGreaterThanEqual(
      account.getId(), CreditGrantSource.AD_REWARD, now.toLocalDate().atStartOfDay());
    if (today >= settings.dailyLimit()) {
      return AdRewardRejectReason.DAILY_LIMIT;
    }
    return null;
  }

  /// 로그에는 nonce 앞 몇 글자만 남긴다(비밀에 가깝다).
  private static String preview(String value) {
    return value == null ? "" : value.substring(0, Math.min(6, value.length()));
  }
}
