package com.chuseok22.elumserver.credit.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import com.chuseok22.elumserver.credit.application.dto.response.CreditSummaryResponse.BreakdownLine;
import com.chuseok22.elumserver.credit.core.CreditBreakdownKind;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import jakarta.persistence.EntityManager;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 종류별 줄: 합계가 잔액과 맞아야 앱이 그린 게이지가 총량과 어긋나지 않는다
class CreditBreakdownServiceTest {

  private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");
  /// 2026-11-10(화) 15:00 — 2026-W46
  private static final LocalDateTime NOW = LocalDateTime.of(2026, 11, 10, 15, 0);

  private static BreakdownLine lineOf(List<BreakdownLine> lines, CreditBreakdownKind kind) {
    return lines.stream().filter(line -> line.kind() == kind).findFirst().orElseThrow();
  }

  @Test
  @DisplayName("종류 합계 남음 = 사용 가능 + 예약 — 어긋나면 앱의 게이지 합이 위 총량과 다르다")
  void remainingSum_equalsAvailablePlusReserved() {
    CreditTestStore store = new CreditTestStore();
    AiCreditAccountRepository accountRepository = mock(AiCreditAccountRepository.class);
    AiCreditGrantRepository grantRepository = mock(AiCreditGrantRepository.class);
    AiCreditJobRepository jobRepository = mock(AiCreditJobRepository.class);
    AiCreditLedgerRepository ledgerRepository = mock(AiCreditLedgerRepository.class);
    store.wire(accountRepository, grantRepository, jobRepository, ledgerRepository);
    CreditAccountService accountService = new CreditAccountService(accountRepository, grantRepository, jobRepository,
      ledgerRepository, CreditTestStore.weekPeriodSettings(), mock(EntityManager.class));
    AiCreditAccount account = store.account("acc-a", "member-a");
    store.weekly("acc-a", NOW, 10, 6);
    store.grant("acc-a", CreditGrantSource.ADMIN_BONUS, 5, 3, NOW.minusDays(1), NOW.plusDays(5));
    store.grant("acc-a", CreditGrantSource.AD_REWARD, 2, 2, NOW.minusHours(1), NOW.plusDays(2));
    store.grant("acc-a", CreditGrantSource.PURCHASE, 50, 18, NOW.minusDays(2), null);
    store.reservedJob("acc-a", "key-1", CreditJobKind.ROUTINE_CREATE, 4, NOW.minusMinutes(1));

    List<BreakdownLine> lines = CreditBreakdownService.linesOf(
      store.grants.stream().filter(grant -> grant.isValidAt(NOW)).toList(), ZONE);
    int remainingSum = lines.stream().mapToInt(BreakdownLine::remaining).sum();
    CreditBalance balance = accountService.balance(account, NOW);

    assertThat(remainingSum).isEqualTo(balance.available() + balance.reserved());
    assertThat(lines).extracting(BreakdownLine::kind)
      .containsExactly(CreditBreakdownKind.PERIODIC, CreditBreakdownKind.BONUS, CreditBreakdownKind.PURCHASED);
  }

  @Test
  @DisplayName("PERIODIC 은 받은 양·쓴 양·남은 양과 만료를 채우고, BONUS 는 가장 먼저 끝나는 묶음의 만료를 쓴다")
  void lines_carryAmountsAndEarliestExpiry() {
    AiCreditGrant periodic = grant(CreditGrantSource.WEEKLY, 10, 6, LocalDateTime.of(2026, 11, 16, 0, 0));
    AiCreditGrant bonusLate = grant(CreditGrantSource.ADMIN_BONUS, 5, 3, LocalDateTime.of(2026, 11, 30, 0, 0));
    AiCreditGrant bonusSoon = grant(CreditGrantSource.AD_REWARD, 2, 2, LocalDateTime.of(2026, 11, 12, 0, 0));
    AiCreditGrant purchased = grant(CreditGrantSource.PURCHASE, 50, 18, null);

    List<BreakdownLine> lines = CreditBreakdownService.linesOf(List.of(periodic, bonusLate, bonusSoon, purchased), ZONE);

    BreakdownLine periodicLine = lineOf(lines, CreditBreakdownKind.PERIODIC);
    assertThat(periodicLine.granted()).isEqualTo(10);
    assertThat(periodicLine.used()).isEqualTo(4);
    assertThat(periodicLine.remaining()).isEqualTo(6);
    assertThat(periodicLine.expiresAt()).isEqualTo(OffsetDateTime.parse("2026-11-16T00:00:00+09:00"));
    BreakdownLine bonusLine = lineOf(lines, CreditBreakdownKind.BONUS);
    assertThat(bonusLine.granted()).isEqualTo(7);
    assertThat(bonusLine.remaining()).isEqualTo(5);
    assertThat(bonusLine.expiresAt()).isEqualTo(OffsetDateTime.parse("2026-11-12T00:00:00+09:00"));
    BreakdownLine purchasedLine = lineOf(lines, CreditBreakdownKind.PURCHASED);
    assertThat(purchasedLine.granted()).isEqualTo(50);
    assertThat(purchasedLine.used()).isEqualTo(32);
    assertThat(purchasedLine.remaining()).isEqualTo(18);
    assertThat(purchasedLine.expiresAt()).isNull();
  }

  @Test
  @DisplayName("PERIODIC 은 지급이 없어도 한 줄이고, 구매·보너스는 없으면 줄이 없다")
  void periodicAlwaysShown_othersOnlyWhenPresent() {
    List<BreakdownLine> lines = CreditBreakdownService.linesOf(List.of(), ZONE);

    assertThat(lines).singleElement().satisfies(line -> {
      assertThat(line.kind()).isEqualTo(CreditBreakdownKind.PERIODIC);
      assertThat(line.granted()).isZero();
      assertThat(line.expiresAt()).isNull();
    });
  }

  private static AiCreditGrant grant(CreditGrantSource source, int amount, int remaining, LocalDateTime expiresAt) {
    AiCreditGrant grant = new AiCreditGrant();
    grant.setSource(source);
    grant.setAmount(amount);
    grant.setRemaining(remaining);
    grant.setValidFrom(NOW.minusDays(1));
    grant.setExpiresAt(expiresAt);
    return grant;
  }
}
