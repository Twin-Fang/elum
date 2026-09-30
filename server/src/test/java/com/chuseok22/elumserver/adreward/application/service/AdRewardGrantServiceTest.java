package com.chuseok22.elumserver.adreward.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.adreward.core.AdRewardRejectReason;
import com.chuseok22.elumserver.adreward.core.AdRewardStatus;
import com.chuseok22.elumserver.adreward.infrastructure.entity.AdRewardSession;
import com.chuseok22.elumserver.adreward.infrastructure.repository.AdRewardSessionRepository;
import com.chuseok22.elumserver.credit.application.service.CreditAccountService;
import com.chuseok22.elumserver.credit.application.service.CreditTestStore;
import com.chuseok22.elumserver.credit.core.CreditAccountStatus;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import jakarta.persistence.EntityManager;
import java.time.Clock;
import java.time.Instant;
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
 * 광고를 보고 크레딧을 받는 **지급의 핵심** (#463).
 *
 * <p>크레딧은 AI 비용이다. 지급이 두 번 되거나, 검증 없이 되거나, 한도를 넘어 되면 비용이 샌다. 반대로 정상 시청에
 * 지급이 안 되면 사용자가 속았다고 느낀다. 그래서 정상 한 가지보다 **막아야 하는 경우를 하나씩** 본다.
 */
@ExtendWith(MockitoExtension.class)
class AdRewardGrantServiceTest {

  private static final String MEMBER_ID = "m1";
  private static final String ACCOUNT_ID = "acc1";
  private static final String NONCE = "nonce-1";
  private static final String TX = "tx-1";
  private static final String AD_UNIT = "6517734434";
  /// 2026-09-30(수) 15:00 — 2026-W40(09-28 ~ 10-05).
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
  private AdRewardGrantService service;
  private AiCreditAccount account;

  @BeforeEach
  void setUp() {
    store.wire(accountRepository, grantRepository, jobRepository, ledgerRepository);
    CreditAccountService accountService =
      new CreditAccountService(accountRepository, grantRepository, jobRepository, ledgerRepository, entityManager);
    service = new AdRewardGrantService(settings, sessionRepository, accountService, grantRepository, ledgerRepository, CLOCK);

    account = new AiCreditAccount();
    account.setId(ACCOUNT_ID);
    account.setMemberId(MEMBER_ID);
    store.accounts.add(account);

    lenient().when(settings.enabled()).thenReturn(true);
    lenient().when(settings.creditsPerView()).thenReturn(2);
    lenient().when(settings.dailyLimit()).thenReturn(3);
    lenient().when(settings.isAllowedAdUnit(AD_UNIT)).thenReturn(true);

    lenient().when(sessionRepository.findByNonceForUpdate(anyString())).thenAnswer(inv -> sessions.stream()
      .filter(s -> s.getNonce().equals(inv.getArgument(0))).findFirst());
    lenient().when(sessionRepository.existsByTransactionId(anyString())).thenAnswer(inv -> sessions.stream()
      .anyMatch(s -> inv.getArgument(0).equals(s.getTransactionId())));
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

  // --- 정상 ---

  @Test
  void 정상_시청이면_크레딧을_주고_세션을_지급됨으로_바꾼다() {
    AdRewardSession session = pendingSession(NONCE);

    AdRewardResult result = service.grant(callback(NONCE, TX));

    assertThat(result.outcome()).isEqualTo(AdRewardOutcome.GRANTED);
    assertThat(session.getStatus()).isEqualTo(AdRewardStatus.GRANTED);
    assertThat(session.getGrantedCredits()).isEqualTo(2);
    assertThat(session.getTransactionId()).isEqualTo(TX);
    assertThat(session.getGrantedAt()).isEqualTo(NOW);
    assertThat(store.grants).hasSize(1);
    AiCreditGrant grant = store.grants.get(0);
    assertThat(grant.getSource()).isEqualTo(CreditGrantSource.AD_REWARD);
    assertThat(grant.getAmount()).isEqualTo(2);
    assertThat(grant.getRemaining()).isEqualTo(2);
    assertThat(grant.getRefId()).isEqualTo("ad:" + TX);
    assertThat(session.getGrantId()).isEqualTo(grant.getId());
  }

  @Test
  void 지급한_크레딧은_이번_주_끝에_만료된다() {
    pendingSession(NONCE);

    service.grant(callback(NONCE, TX));

    // 2026-09-30 은 수요일, 이번 주는 다음 월요일(10-05) 0시에 끝난다.
    assertThat(store.grants.get(0).getExpiresAt()).isEqualTo(LocalDateTime.of(2026, 10, 5, 0, 0));
    assertThat(store.grants.get(0).getValidFrom()).isEqualTo(NOW);
  }

  @Test
  void 원장에_지급_한_줄을_남기고_합계가_맞는다() {
    pendingSession(NONCE);

    service.grant(callback(NONCE, TX));

    assertThat(store.ledger).hasSize(1);
    var line = store.ledger.get(0);
    assertThat(line.getType()).isEqualTo(CreditLedgerType.GRANT);
    assertThat(line.getDelta()).isEqualTo(2);
    assertThat(line.getBalanceAfter()).isEqualTo(2);
    assertThat(line.getAccountId()).isEqualTo(ACCOUNT_ID);
    assertThat(line.getGrantId()).isEqualTo(store.grants.get(0).getId());
    assertThat(line.getActor()).isEqualTo("system");
  }

  @Test
  void 이미_남은_크레딧이_있으면_그_위에_더한다() {
    store.grants.add(grantOf(5));
    pendingSession(NONCE);

    service.grant(callback(NONCE, TX));

    assertThat(store.ledger.get(0).getBalanceAfter()).isEqualTo(7);
  }

  // --- 이중 지급 (가장 중요) ---

  @Test
  void 같은_콜백이_두_번_와도_한_번만_준다() {
    pendingSession(NONCE);

    AdRewardResult first = service.grant(callback(NONCE, TX));
    AdRewardResult second = service.grant(callback(NONCE, TX));

    assertThat(first.outcome()).isEqualTo(AdRewardOutcome.GRANTED);
    assertThat(second.outcome()).isEqualTo(AdRewardOutcome.DUPLICATE);
    assertThat(store.grants).hasSize(1);
    assertThat(store.ledger).hasSize(1);
  }

  @Test
  void 같은_transactionId를_다른_세션으로_보내도_한_번만_준다() {
    pendingSession("nonce-a");
    pendingSession("nonce-b");

    service.grant(callback("nonce-a", TX));
    AdRewardResult replay = service.grant(callback("nonce-b", TX));

    assertThat(replay.outcome()).isEqualTo(AdRewardOutcome.DUPLICATE);
    assertThat(store.grants).hasSize(1);
    // 재사용을 시도한 세션은 지급되지 않은 채 남는다.
    assertThat(sessionOf("nonce-b").getStatus()).isEqualTo(AdRewardStatus.PENDING);
  }

  @Test
  void 이미_지급된_세션에_새_시청이_와도_더_주지_않고_세션을_바꾸지_않는다() {
    AdRewardSession session = pendingSession(NONCE);
    service.grant(callback(NONCE, TX));

    AdRewardResult again = service.grant(callback(NONCE, "tx-2"));

    assertThat(again.outcome()).isEqualTo(AdRewardOutcome.REJECTED);
    assertThat(again.reason()).isEqualTo(AdRewardRejectReason.NOT_PENDING);
    assertThat(session.getStatus()).isEqualTo(AdRewardStatus.GRANTED);
    assertThat(session.getTransactionId()).isEqualTo(TX);
    assertThat(store.grants).hasSize(1);
  }

  // --- 막아야 하는 것 ---

  @Test
  void 알_수_없는_nonce는_무시하고_아무것도_주지_않는다() {
    AdRewardResult result = service.grant(callback("없는-nonce", TX));

    assertThat(result.outcome()).isEqualTo(AdRewardOutcome.IGNORED);
    assertThat(store.grants).isEmpty();
    assertThat(store.ledger).isEmpty();
  }

  @Test
  void 유효_시간이_지난_세션은_만료로_바꾸고_주지_않는다() {
    AdRewardSession session = pendingSession(NONCE);
    session.setExpiresAt(NOW.minusMinutes(1));

    AdRewardResult result = service.grant(callback(NONCE, TX));

    assertThat(result.outcome()).isEqualTo(AdRewardOutcome.REJECTED);
    assertThat(result.reason()).isEqualTo(AdRewardRejectReason.EXPIRED);
    assertThat(session.getStatus()).isEqualTo(AdRewardStatus.EXPIRED);
    assertThat(store.grants).isEmpty();
  }

  @Test
  void 기능이_꺼져_있으면_주지_않고_사유를_남긴다() {
    when(settings.enabled()).thenReturn(false);
    AdRewardSession session = pendingSession(NONCE);

    AdRewardResult result = service.grant(callback(NONCE, TX));

    assertThat(result.reason()).isEqualTo(AdRewardRejectReason.DISABLED);
    assertThat(session.getStatus()).isEqualTo(AdRewardStatus.REJECTED);
    assertThat(session.getRejectReason()).isEqualTo(AdRewardRejectReason.DISABLED);
    assertThat(store.grants).isEmpty();
  }

  @Test
  void 허용하지_않은_광고_단위는_주지_않는다() {
    AdRewardSession session = pendingSession(NONCE);

    AdRewardResult result = service.grant(new SsvCallback("9999999999", NONCE, TX, MEMBER_ID));

    assertThat(result.reason()).isEqualTo(AdRewardRejectReason.AD_UNIT);
    assertThat(session.getStatus()).isEqualTo(AdRewardStatus.REJECTED);
    assertThat(store.grants).isEmpty();
  }

  @Test
  void 멈춘_계정에는_주지_않는다() {
    account.setStatus(CreditAccountStatus.FROZEN);
    AdRewardSession session = pendingSession(NONCE);

    AdRewardResult result = service.grant(callback(NONCE, TX));

    assertThat(result.reason()).isEqualTo(AdRewardRejectReason.FROZEN);
    assertThat(session.getStatus()).isEqualTo(AdRewardStatus.REJECTED);
    assertThat(store.grants).isEmpty();
  }

  @Test
  void 하루_상한에_닿았으면_주지_않는다() {
    grantedToday("t1");
    grantedToday("t2");
    grantedToday("t3");
    AdRewardSession session = pendingSession(NONCE);

    AdRewardResult result = service.grant(callback(NONCE, TX));

    assertThat(result.reason()).isEqualTo(AdRewardRejectReason.DAILY_LIMIT);
    assertThat(session.getStatus()).isEqualTo(AdRewardStatus.REJECTED);
    // 미리 받은 3개 그대로다 — 새 묶음도 원장 줄도 늘지 않았다.
    assertThat(store.grants).hasSize(3);
    assertThat(store.ledger).isEmpty();
  }

  @Test
  void 탈퇴하고_다시_가입해_회원_ID가_바뀌어도_오늘_받은_횟수가_이어진다() {
    // 크레딧 계정은 소셜 신원으로 재가입 뒤에도 이어진다(회원 ID 만 새로 붙는다). 상한을 회원 ID 로 세면
    // 탈퇴·재가입만으로 오늘 상한이 리셋돼 같은 사람이 광고 크레딧을 더 받는다.
    grantedToday("t1");
    grantedToday("t2");
    grantedToday("t3");
    account.setMemberId("m2-재가입");
    AdRewardSession session = pendingSession(NONCE);
    session.setMemberId("m2-재가입");

    AdRewardResult result = service.grant(callback(NONCE, TX));

    assertThat(result.reason()).isEqualTo(AdRewardRejectReason.DAILY_LIMIT);
    assertThat(store.grants).hasSize(3);
  }

  @Test
  void 상한_바로_아래면_마지막_한_번은_준다() {
    grantedToday("t1");
    grantedToday("t2");
    pendingSession(NONCE);

    AdRewardResult result = service.grant(callback(NONCE, TX));

    assertThat(result.outcome()).isEqualTo(AdRewardOutcome.GRANTED);
  }

  @Test
  void 어제_받은_것은_오늘_상한에_세지_않는다() {
    for (int i = 0; i < 5; i++) {
      adRewardGrantAt(NOW.minusDays(1), "old-tx-" + i);
    }
    pendingSession(NONCE);

    AdRewardResult result = service.grant(callback(NONCE, TX));

    assertThat(result.outcome()).isEqualTo(AdRewardOutcome.GRANTED);
  }

  @Test
  void 이미_거절된_세션에_다시_콜백이_와도_주지_않는다() {
    when(settings.enabled()).thenReturn(false);
    pendingSession(NONCE);
    service.grant(callback(NONCE, TX));
    // 다시 켜도 이미 끝난 세션은 살아나지 않는다 — 상태를 먼저 보므로 설정은 읽히지도 않는다.
    lenient().when(settings.enabled()).thenReturn(true);

    AdRewardResult retry = service.grant(callback(NONCE, TX));

    assertThat(retry.outcome()).isEqualTo(AdRewardOutcome.REJECTED);
    assertThat(retry.reason()).isEqualTo(AdRewardRejectReason.NOT_PENDING);
    assertThat(store.grants).isEmpty();
  }

  // --- 실패 안전 ---

  @Test
  void 원장_저장이_실패하면_세션을_지급됨으로_바꾸지_않는다() {
    AdRewardSession session = pendingSession(NONCE);
    when(ledgerRepository.save(any())).thenThrow(new IllegalStateException("DB 오류"));

    assertThatThrownBy(() -> service.grant(callback(NONCE, TX))).isInstanceOf(IllegalStateException.class);

    // 트랜잭션이 롤백되면 묶음도 사라진다. 그래도 세션은 지급됨으로 바뀌지 않아야 다음 재시도가 지급할 수 있다.
    assertThat(session.getStatus()).isEqualTo(AdRewardStatus.PENDING);
    assertThat(session.getTransactionId()).isNull();
  }

  // ---------------------------------------------------------------------------------------------

  private AdRewardSession pendingSession(String nonce) {
    AdRewardSession session = new AdRewardSession();
    session.setId(UUID.randomUUID().toString());
    session.setMemberId(MEMBER_ID);
    session.setNonce(nonce);
    session.setStatus(AdRewardStatus.PENDING);
    session.setExpiresAt(NOW.plusMinutes(30));
    sessions.add(session);
    return session;
  }

  /// 오늘 광고로 이미 받은 묶음 하나. 상한은 세션이 아니라 이 묶음 수로 센다.
  private void grantedToday(String tx) {
    adRewardGrantAt(NOW.minusHours(1), tx);
  }

  private void adRewardGrantAt(LocalDateTime at, String tx) {
    AiCreditGrant grant = grantOf(2);
    grant.setSource(CreditGrantSource.AD_REWARD);
    grant.setPeriodKey(null);
    grant.setValidFrom(at);
    grant.setRefId("ad:" + tx);
    store.grants.add(grant);
  }

  private AdRewardSession sessionOf(String nonce) {
    return sessions.stream().filter(s -> s.getNonce().equals(nonce)).findFirst().orElseThrow();
  }

  private static SsvCallback callback(String nonce, String tx) {
    return new SsvCallback(AD_UNIT, nonce, tx, MEMBER_ID);
  }

  private AiCreditGrant grantOf(int amount) {
    AiCreditGrant grant = new AiCreditGrant();
    grant.setId(UUID.randomUUID().toString());
    grant.setAccountId(ACCOUNT_ID);
    grant.setSource(CreditGrantSource.WEEKLY);
    grant.setAmount(amount);
    grant.setRemaining(amount);
    grant.setValidFrom(LocalDateTime.of(2026, 9, 28, 0, 0));
    grant.setExpiresAt(LocalDateTime.of(2026, 10, 5, 0, 0));
    grant.setPeriodKey("2026-W40");
    return grant;
  }
}
