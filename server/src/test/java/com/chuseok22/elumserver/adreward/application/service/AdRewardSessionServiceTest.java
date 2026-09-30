package com.chuseok22.elumserver.adreward.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;

import com.chuseok22.elumserver.adreward.core.AdRewardRejectReason;
import com.chuseok22.elumserver.adreward.core.AdRewardStatus;
import com.chuseok22.elumserver.adreward.infrastructure.entity.AdRewardSession;
import com.chuseok22.elumserver.adreward.infrastructure.repository.AdRewardSessionRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.application.service.CreditTestStore;
import com.chuseok22.elumserver.credit.core.CreditAccountStatus;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import jakarta.persistence.EntityManager;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 광고 보상 세션을 만들고 조회한다 (#463). 세션은 광고 한 번을 회원에 묶는 유일한 끈이라
 * 남의 세션을 보지 못하고, 상한을 넘어 만들지 못하고, 꺼져 있으면 만들지 못해야 한다.
 */
@ExtendWith(MockitoExtension.class)
class AdRewardSessionServiceTest {

  private static final String MEMBER_ID = "m1";
  private static final String ACCOUNT_ID = "acc1";
  private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 30, 15, 0);
  private static final Clock CLOCK = Clock.fixed(NOW.atZone(ZoneId.systemDefault()).toInstant(), ZoneId.systemDefault());

  @Mock
  private AiCreditAccountRepository accountRepository;
  @Mock
  private AiCreditGrantRepository grantRepository;
  @Mock
  private AiCreditJobRepository jobRepository;
  @Mock
  private AiCreditLedgerRepository ledgerRepository;
  @Mock
  private EntityManager entityManager;
  @Mock
  private AdRewardSessionRepository sessionRepository;
  @Mock
  private AdRewardSettings settings;

  private final CreditTestStore store = new CreditTestStore();
  private final List<AdRewardSession> sessions = new ArrayList<>();
  private AdRewardSessionService service;
  private AiCreditAccount account;

  @BeforeEach
  void setUp() {
    store.wire(accountRepository, grantRepository, jobRepository, ledgerRepository);
    CreditAccountService accountService =
      new CreditAccountService(accountRepository, grantRepository, jobRepository, ledgerRepository, entityManager);
    service = new AdRewardSessionService(settings, sessionRepository, accountService, grantRepository, CLOCK);

    account = new AiCreditAccount();
    account.setId(ACCOUNT_ID);
    account.setMemberId(MEMBER_ID);
    store.accounts.add(account);

    lenient().when(settings.enabled()).thenReturn(true);
    lenient().when(settings.creditsPerView()).thenReturn(2);
    lenient().when(settings.dailyLimit()).thenReturn(3);
    lenient().when(settings.sessionTtl()).thenReturn(Duration.ofMinutes(30));

    lenient().when(sessionRepository.findByNonce(anyString())).thenAnswer(inv -> sessions.stream()
      .filter(s -> s.getNonce().equals(inv.getArgument(0))).findFirst());
    lenient().when(sessionRepository.findFirstByMemberIdAndStatusAndExpiresAtAfterOrderByCreatedAtDesc(
      anyString(), any(), any())).thenAnswer(inv -> sessions.stream()
      .filter(s -> s.getMemberId().equals(inv.getArgument(0)) && s.getStatus() == inv.getArgument(1)
        && s.getExpiresAt().isAfter(inv.getArgument(2)))
      .findFirst());
    lenient().when(sessionRepository.save(any(AdRewardSession.class))).thenAnswer(inv -> {
      AdRewardSession session = inv.getArgument(0);
      if (session.getId() == null) {
        session.setId(UUID.randomUUID().toString());
      }
      if (!sessions.contains(session)) {
        sessions.add(session);
      }
      return session;
    });
  }

  // --- 제안 (앱이 "광고 보고 더 만들기"를 보일지) ---

  @Test
  void 켜져_있으면_지급량과_오늘_남은_횟수를_알려준다() {
    AdRewardOffer offer = service.offer(MEMBER_ID);

    assertThat(offer.enabled()).isTrue();
    assertThat(offer.creditsPerView()).isEqualTo(2);
    assertThat(offer.remainingToday()).isEqualTo(3);
  }

  @Test
  void 꺼져_있으면_제안하지_않는다() {
    lenient().when(settings.enabled()).thenReturn(false);

    AdRewardOffer offer = service.offer(MEMBER_ID);

    assertThat(offer.enabled()).isFalse();
    assertThat(offer.remainingToday()).isZero();
  }

  @Test
  void 오늘_받은_만큼_남은_횟수가_줄고_0_아래로_내려가지_않는다() {
    for (int i = 0; i < 5; i++) {
      grantedToday("g" + i);
    }

    AdRewardOffer offer = service.offer(MEMBER_ID);

    assertThat(offer.remainingToday()).isZero();
    // 남은 횟수가 없으면 앱은 버튼을 숨긴다.
    assertThat(offer.enabled()).isFalse();
  }

  @Test
  void 멈춘_계정에는_제안하지_않는다() {
    account.setStatus(CreditAccountStatus.FROZEN);

    assertThat(service.offer(MEMBER_ID).enabled()).isFalse();
  }

  // --- 세션 만들기 ---

  @Test
  void 세션을_만들면_추측할_수_없는_nonce와_만료_시각을_준다() {
    AdRewardSessionInfo info = service.create(MEMBER_ID);

    assertThat(info.nonce()).hasSizeGreaterThanOrEqualTo(40);
    assertThat(info.expiresAt()).isEqualTo(NOW.plusMinutes(30));
    assertThat(info.creditsPerView()).isEqualTo(2);
    assertThat(info.remainingToday()).isEqualTo(3);
    assertThat(sessions).hasSize(1);
    assertThat(sessions.get(0).getMemberId()).isEqualTo(MEMBER_ID);
    assertThat(sessions.get(0).getStatus()).isEqualTo(AdRewardStatus.PENDING);
  }

  @Test
  void 세션마다_nonce가_다르다() {
    String first = service.create(MEMBER_ID).nonce();
    sessions.get(0).setStatus(AdRewardStatus.GRANTED);

    String second = service.create(MEMBER_ID).nonce();

    assertThat(second).isNotEqualTo(first);
  }

  @Test
  void 기다리는_세션이_있으면_새로_만들지_않고_다시_쓴다() {
    String first = service.create(MEMBER_ID).nonce();
    String second = service.create(MEMBER_ID).nonce();

    assertThat(second).isEqualTo(first);
    assertThat(sessions).hasSize(1);
  }

  @Test
  void 만료된_세션은_다시_쓰지_않고_새로_만든다() {
    String first = service.create(MEMBER_ID).nonce();
    sessions.get(0).setExpiresAt(NOW.minusMinutes(1));

    String second = service.create(MEMBER_ID).nonce();

    assertThat(second).isNotEqualTo(first);
    assertThat(sessions).hasSize(2);
  }

  @Test
  void 꺼져_있으면_만들지_못한다() {
    lenient().when(settings.enabled()).thenReturn(false);

    assertThatCode(() -> service.create(MEMBER_ID), ErrorCode.AD_REWARD_DISABLED);
    assertThat(sessions).isEmpty();
  }

  @Test
  void 멈춘_계정은_만들지_못한다() {
    account.setStatus(CreditAccountStatus.FROZEN);

    assertThatCode(() -> service.create(MEMBER_ID), ErrorCode.AD_REWARD_ACCOUNT_FROZEN);
    assertThat(sessions).isEmpty();
  }

  @Test
  void 하루_상한에_닿았으면_만들지_못한다() {
    grantedToday("a");
    grantedToday("b");
    grantedToday("c");

    assertThatCode(() -> service.create(MEMBER_ID), ErrorCode.AD_REWARD_DAILY_LIMIT);
  }

  // --- 상태 조회 ---

  @Test
  void 내_세션의_상태를_돌려준다() {
    String nonce = service.create(MEMBER_ID).nonce();

    AdRewardSessionStatus status = service.status(MEMBER_ID, nonce);

    assertThat(status.status()).isEqualTo(AdRewardStatus.PENDING);
    assertThat(status.grantedCredits()).isZero();
  }

  @Test
  void 지급된_세션은_지급량을_알려준다() {
    String nonce = service.create(MEMBER_ID).nonce();
    AdRewardSession session = sessions.get(0);
    session.setStatus(AdRewardStatus.GRANTED);
    session.setGrantedCredits(2);

    AdRewardSessionStatus status = service.status(MEMBER_ID, nonce);

    assertThat(status.status()).isEqualTo(AdRewardStatus.GRANTED);
    assertThat(status.grantedCredits()).isEqualTo(2);
  }

  @Test
  void 거절된_세션은_사유를_알려준다() {
    String nonce = service.create(MEMBER_ID).nonce();
    AdRewardSession session = sessions.get(0);
    session.setStatus(AdRewardStatus.REJECTED);
    session.setRejectReason(AdRewardRejectReason.DAILY_LIMIT);

    assertThat(service.status(MEMBER_ID, nonce).reason()).isEqualTo(AdRewardRejectReason.DAILY_LIMIT);
  }

  @Test
  void 기다리는_세션이_유효_시간을_넘기면_만료로_보여준다() {
    String nonce = service.create(MEMBER_ID).nonce();
    sessions.get(0).setExpiresAt(NOW.minusMinutes(1));

    assertThat(service.status(MEMBER_ID, nonce).status()).isEqualTo(AdRewardStatus.EXPIRED);
  }

  @Test
  void 남의_세션은_볼_수_없다() {
    String nonce = service.create(MEMBER_ID).nonce();

    // 존재를 알려 주지 않는다 — 없는 것과 같은 응답이다.
    assertThatCode(() -> service.status("다른-회원", nonce), ErrorCode.AD_REWARD_SESSION_NOT_FOUND);
  }

  @Test
  void 없는_nonce는_찾을_수_없다() {
    assertThatCode(() -> service.status(MEMBER_ID, "없는-nonce"), ErrorCode.AD_REWARD_SESSION_NOT_FOUND);
  }

  // ---------------------------------------------------------------------------------------------

  /// 오늘 광고로 이미 받은 묶음 하나. 상한은 세션이 아니라 계정의 이 묶음 수로 센다.
  private void grantedToday(String tx) {
    AiCreditGrant grant = new AiCreditGrant();
    grant.setId(UUID.randomUUID().toString());
    grant.setAccountId(ACCOUNT_ID);
    grant.setSource(CreditGrantSource.AD_REWARD);
    grant.setAmount(2);
    grant.setRemaining(2);
    grant.setValidFrom(NOW.minusHours(1));
    grant.setRefId("ad:" + tx);
    store.grants.add(grant);
  }

  private static void assertThatCode(Runnable action, ErrorCode expected) {
    assertThatThrownBy(action::run)
      .isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode())
      .isEqualTo(expected);
  }
}
