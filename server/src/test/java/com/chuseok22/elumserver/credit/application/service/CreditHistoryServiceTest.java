package com.chuseok22.elumserver.credit.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.credit.application.dto.response.CreditHistoryResponse;
import com.chuseok22.elumserver.credit.application.dto.response.CreditHistoryResponse.Entry;
import com.chuseok22.elumserver.credit.core.CreditAction;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditHistoryKind;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditAccount;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.routine.application.service.RoutineQueryService;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.SliceImpl;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 보호자 크레딧 내역 변환 (#658): 일과 사용 > 글·그림 두 줄, 지급 출처별 종류, 지워진 일과·계정 없음.
 */
@ExtendWith(MockitoExtension.class)
class CreditHistoryServiceTest {

  private static final String MEMBER_ID = "m1";
  private static final String ACCOUNT_ID = "acc1";
  private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-10-01T02:30:00Z"), ZoneId.of("Asia/Seoul"));
  private static final LocalDateTime SETTLED_AT = LocalDateTime.of(2026, 10, 1, 11, 23);
  private static final LocalDateTime STARTED_AT = LocalDateTime.of(2026, 10, 1, 11, 22);
  /// 일과 글 1 + 그림 1장당 1
  private static final String COSTS = "{\"ROUTINE_TEXT\":1,\"CARD_IMAGE\":1,\"IMAGE_REGENERATE\":1}";

  @Mock private AiCreditLedgerRepository ledgerRepository;
  @Mock private AiCreditJobRepository jobRepository;
  @Mock private AiCreditGrantRepository grantRepository;
  @Mock private RoutineQueryService routineQueryService;
  @Mock private CreditAccountService accountService;

  private CreditHistoryService service;

  @BeforeEach
  void setUp() {
    service = new CreditHistoryService(ledgerRepository, jobRepository, grantRepository, routineQueryService,
      accountService, CLOCK);
    AiCreditAccount account = new AiCreditAccount();
    account.setId(ACCOUNT_ID);
    // 계정 없음 시험은 이 줄을 쓰지 않는다
    lenient().when(accountService.findAccount(MEMBER_ID)).thenReturn(Optional.of(account));
  }

  @Test
  @DisplayName("일과 사용 한 줄이 글 몫과 그림 몫 두 줄로 나뉘고 일과 제목이 붙는다")
  void splitsRoutineConsumeIntoTextAndImageEntries() {
    stubPage(consumeLine("l1", "job1", -5));
    stubJob("job1", CreditJobKind.ROUTINE_CREATE, 4, "r1");
    stubRoutineTitle("r1", "스스로 옷을 입어요");

    List<Entry> entries = service.getMine(MEMBER_ID, 0, 30).entries();

    assertThat(entries).extracting(Entry::kind)
      .containsExactly(CreditHistoryKind.CARD_IMAGES, CreditHistoryKind.ROUTINE_TEXT);
    assertThat(entries).extracting(Entry::delta).containsExactly(-4, -1);
    assertThat(entries).extracting(Entry::cardCount).containsExactly(4, null);
    assertThat(entries).extracting(Entry::routineTitle).containsOnly("스스로 옷을 입어요");
    // 그림 줄은 정산 시각, 글 줄은 작업 시작 시각
    assertThat(entries).extracting(Entry::occurredAt).containsExactly(SETTLED_AT, STARTED_AT);
    assertThat(entries.get(0).occurredAtOffset().toString()).isEqualTo("2026-10-01T11:23+09:00");
  }

  @Test
  @DisplayName("잔액이 모자라 덜 차감된 일과는 글 몫을 먼저 채운다")
  void fillsTextShareFirstWhenChargedLessThanBilled() {
    stubPage(consumeLine("l1", "job1", -1));
    stubJob("job1", CreditJobKind.ROUTINE_CREATE, 4, "r1");
    stubRoutineTitle("r1", "양치하기");

    List<Entry> entries = service.getMine(MEMBER_ID, 0, 30).entries();

    assertThat(entries).extracting(Entry::kind).containsExactly(CreditHistoryKind.ROUTINE_TEXT);
    assertThat(entries).extracting(Entry::delta).containsExactly(-1);
  }

  @Test
  @DisplayName("지워진 일과의 사용 줄은 제목 없이 나온다")
  void showsEntryWithoutTitleWhenRoutineDeleted() {
    stubPage(consumeLine("l1", "job1", -3));
    stubJob("job1", CreditJobKind.ROUTINE_CREATE, 2, "gone");
    when(routineQueryService.findTitlesByIds(any())).thenReturn(Map.of());

    List<Entry> entries = service.getMine(MEMBER_ID, 0, 30).entries();

    assertThat(entries).hasSize(2);
    assertThat(entries).extracting(Entry::routineTitle).containsOnlyNulls();
  }

  @Test
  @DisplayName("지급은 출처로 종류가 갈리고 증감 0 줄은 숨는다")
  void mapsGrantSourceAndHidesZeroDelta() {
    AiCreditLedger weekly = line("g1", CreditLedgerType.GRANT, 100);
    weekly.setGrantId("grant1");
    AiCreditLedger ad = line("g2", CreditLedgerType.GRANT, 2);
    ad.setGrantId("grant2");
    AiCreditLedger zero = line("z1", CreditLedgerType.CONSUME, 0);
    stubPage(weekly, ad, zero);
    stubGrants(grant("grant1", CreditGrantSource.WEEKLY), grant("grant2", CreditGrantSource.AD_REWARD));

    List<Entry> entries = service.getMine(MEMBER_ID, 0, 30).entries();

    assertThat(entries).extracting(Entry::kind)
      .containsExactly(CreditHistoryKind.WEEKLY_GRANT, CreditHistoryKind.AD_REWARD);
    assertThat(entries).extracting(Entry::delta).containsExactly(100, 2);
  }

  @Test
  @DisplayName("계정이 아직 없으면 원장을 읽지 않고 빈 쪽을 돌려준다")
  void returnsEmptyPageWithoutAccount() {
    when(accountService.findAccount("nobody")).thenReturn(Optional.empty());

    CreditHistoryResponse response = service.getMine("nobody", 2, 30);

    assertThat(response.entries()).isEmpty();
    assertThat(response.hasNext()).isFalse();
    assertThat(response.page()).isEqualTo(2);
    verify(ledgerRepository, never()).findByAccountIdAndTypeInOrderByCreatedAtDescIdDesc(any(), anyCollection(), any());
  }

  @Test
  @DisplayName("쪽 크기는 1~50 으로 맞추고 음수 쪽은 0 쪽으로 읽는다")
  void clampsPageAndSize() {
    stubPage();

    service.getMine(MEMBER_ID, -3, 999);

    ArgumentCaptor<Pageable> captor = ArgumentCaptor.forClass(Pageable.class);
    verify(ledgerRepository).findByAccountIdAndTypeInOrderByCreatedAtDescIdDesc(eq(ACCOUNT_ID), anyCollection(),
      captor.capture());
    assertThat(captor.getValue().getPageNumber()).isZero();
    assertThat(captor.getValue().getPageSize()).isEqualTo(CreditHistoryService.MAX_PAGE_SIZE);
  }

  private void stubPage(AiCreditLedger... lines) {
    when(ledgerRepository.findByAccountIdAndTypeInOrderByCreatedAtDescIdDesc(eq(ACCOUNT_ID), anyCollection(), any()))
      .thenReturn(new SliceImpl<>(List.of(lines)));
  }

  private AiCreditLedger consumeLine(String id, String jobId, int delta) {
    AiCreditLedger line = line(id, CreditLedgerType.CONSUME, delta);
    line.setJobId(jobId);
    line.setAction(CreditAction.ROUTINE_TEXT);
    return line;
  }

  private AiCreditLedger line(String id, CreditLedgerType type, int delta) {
    AiCreditLedger line = new AiCreditLedger();
    line.setId(id);
    line.setType(type);
    line.setDelta(delta);
    ReflectionTestUtils.setField(line, "createdAt", SETTLED_AT);
    return line;
  }

  private void stubJob(String jobId, CreditJobKind kind, int imageCount, String routineId) {
    AiCreditJob job = new AiCreditJob();
    job.setId(jobId);
    job.setKind(kind);
    job.setImageCount(imageCount);
    job.setRoutineId(routineId);
    job.setCostSnapshot(COSTS);
    job.setStartedAt(STARTED_AT);
    when(jobRepository.findAllById(any())).thenReturn(List.of(job));
  }

  private void stubRoutineTitle(String routineId, String title) {
    when(routineQueryService.findTitlesByIds(any())).thenReturn(Map.of(routineId, title));
  }

  private void stubGrants(AiCreditGrant... grants) {
    when(grantRepository.findAllById(any())).thenReturn(List.of(grants));
  }

  private AiCreditGrant grant(String grantId, CreditGrantSource source) {
    AiCreditGrant grant = new AiCreditGrant();
    grant.setId(grantId);
    grant.setSource(source);
    return grant;
  }
}
