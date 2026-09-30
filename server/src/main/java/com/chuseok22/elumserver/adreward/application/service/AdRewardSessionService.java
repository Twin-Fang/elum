package com.chuseok22.elumserver.adreward.application.service;

import com.chuseok22.elumserver.adreward.core.AdRewardStatus;
import com.chuseok22.elumserver.adreward.infrastructure.entity.AdRewardSession;
import com.chuseok22.elumserver.adreward.infrastructure.repository.AdRewardSessionRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Base64;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 광고 보상 세션을 만들고 조회한다 (#463).
 *
 * <p>세션은 광고 한 번을 회원에 묶는 **유일한 끈**이다. 그래서 (1) nonce 는 추측할 수 없게 만들고, (2) 남의 세션은 없는
 * 것처럼 답하고, (3) 꺼짐·상한·동결이면 만들지 않는다. 회원마다 기다리는 세션 하나를 다시 쓴다 — 세션을 계속 만들어
 * 표를 키우지 못하게.
 */
@Service
public class AdRewardSessionService {

  private static final SecureRandom RANDOM = new SecureRandom();
  private static final int NONCE_BYTES = 32;

  private final AdRewardSettings settings;
  private final AdRewardSessionRepository sessionRepository;
  private final CreditAccountService accountService;
  private final AiCreditGrantRepository grantRepository;
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 이 앱에는 Clock 빈이 없어 빠뜨리면 서버가 뜨지 않는다.
  @Autowired
  public AdRewardSessionService(
    AdRewardSettings settings, AdRewardSessionRepository sessionRepository, CreditAccountService accountService,
    AiCreditGrantRepository grantRepository
  ) {
    this(settings, sessionRepository, accountService, grantRepository, Clock.systemDefaultZone());
  }

  AdRewardSessionService(
    AdRewardSettings settings, AdRewardSessionRepository sessionRepository, CreditAccountService accountService,
    AiCreditGrantRepository grantRepository, Clock clock
  ) {
    this.settings = settings;
    this.sessionRepository = sessionRepository;
    this.accountService = accountService;
    this.grantRepository = grantRepository;
    this.clock = clock;
  }

  /// 앱이 "광고 보고 더 만들기"를 보일지. 아무것도 쓰지 않는다.
  @Transactional(readOnly = true)
  public AdRewardOffer offer(String memberId) {
    if (!settings.enabled()) {
      return new AdRewardOffer(false, 0, 0);
    }
    LocalDateTime now = LocalDateTime.now(clock);
    AiCreditAccount account = accountService.findAccount(memberId).orElse(null);
    boolean frozen = account != null && account.isFrozen();
    int remaining = (account == null || frozen) ? settings.dailyLimit() : remainingToday(account, now);
    remaining = frozen ? 0 : remaining;
    return new AdRewardOffer(remaining > 0, settings.creditsPerView(), remaining);
  }

  /**
   * 세션을 만든다. 계정을 잠근 안에서 확인하므로 같은 회원의 동시 요청이 상한을 넘겨 만들지 못한다.
   *
   * @throws CustomException 꺼짐(AD_REWARD_DISABLED)·멈춘 계정(AD_REWARD_ACCOUNT_FROZEN)·오늘 상한(AD_REWARD_DAILY_LIMIT)
   */
  @Transactional
  public AdRewardSessionInfo create(String memberId) {
    if (!settings.enabled()) {
      throw new CustomException(ErrorCode.AD_REWARD_DISABLED);
    }
    LocalDateTime now = LocalDateTime.now(clock);
    AiCreditAccount account = accountService.lockAccount(memberId);
    if (account.isFrozen()) {
      throw new CustomException(ErrorCode.AD_REWARD_ACCOUNT_FROZEN);
    }
    int remaining = remainingToday(account, now);
    if (remaining <= 0) {
      throw new CustomException(ErrorCode.AD_REWARD_DAILY_LIMIT);
    }

    AdRewardSession session = sessionRepository
      .findFirstByMemberIdAndStatusAndExpiresAtAfterOrderByCreatedAtDesc(memberId, AdRewardStatus.PENDING, now)
      .orElseGet(() -> {
        AdRewardSession created = new AdRewardSession();
        created.setMemberId(memberId);
        created.setNonce(newNonce());
        created.setStatus(AdRewardStatus.PENDING);
        created.setExpiresAt(now.plus(settings.sessionTtl()));
        return sessionRepository.save(created);
      });
    return new AdRewardSessionInfo(session.getNonce(), session.getExpiresAt(), settings.creditsPerView(), remaining);
  }

  /// 내 세션의 상태. 남의 세션·없는 세션은 똑같이 "없음"으로 답한다(존재를 알려 주지 않는다).
  @Transactional(readOnly = true)
  public AdRewardSessionStatus status(String memberId, String nonce) {
    AdRewardSession session = sessionRepository.findByNonce(nonce)
      .filter(found -> found.getMemberId().equals(memberId))
      .orElseThrow(() -> new CustomException(ErrorCode.AD_REWARD_SESSION_NOT_FOUND));
    AdRewardStatus status = session.getStatus();
    if (status == AdRewardStatus.PENDING && session.isExpiredAt(LocalDateTime.now(clock))) {
      // 저장은 콜백이 오거나 다음 세션을 만들 때 하지 않는다 — 읽기만 하는 곳이라 보여주기만 한다.
      status = AdRewardStatus.EXPIRED;
    }
    return new AdRewardSessionStatus(status, session.getGrantedCredits(), session.getRejectReason());
  }

  /// 오늘 더 받을 수 있는 횟수. **계정의 광고 지급 묶음**으로 센다 — 재가입해도 이어지는 계정이라 상한이 리셋되지 않는다.
  private int remainingToday(AiCreditAccount account, LocalDateTime now) {
    long granted = grantRepository.countByAccountIdAndSourceAndValidFromGreaterThanEqual(
      account.getId(), CreditGrantSource.AD_REWARD, now.toLocalDate().atStartOfDay());
    return (int) Math.max(0, settings.dailyLimit() - granted);
  }

  private static String newNonce() {
    byte[] bytes = new byte[NONCE_BYTES];
    RANDOM.nextBytes(bytes);
    return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
  }
}
