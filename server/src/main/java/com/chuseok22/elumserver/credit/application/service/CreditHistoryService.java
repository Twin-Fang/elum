package com.chuseok22.elumserver.credit.application.service;

import com.chuseok22.elumserver.credit.application.dto.response.CreditHistoryResponse;
import com.chuseok22.elumserver.credit.application.dto.response.CreditHistoryResponse.Entry;
import com.chuseok22.elumserver.credit.core.CreditAction;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.core.CreditHistoryKind;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.credit.core.CreditLedgerType;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditJob;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditLedger;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditJobRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.routine.application.service.RoutineQueryService;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Slice;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 보호자용 크레딧 사용 내역: 원장 한 쪽 조회 > 작업·적립·일과 제목 한 번에 모으기 > 보호자 말로 변환
 * 보이는 원장 종류 4개: 사용(CONSUME), 지급(GRANT), 만료(EXPIRE), 조정(ADJUST). 예약·반환·초과는 숨긴다
 */
@Service
public class CreditHistoryService {

  public static final int DEFAULT_PAGE_SIZE = 30;
  public static final int MAX_PAGE_SIZE = 50;

  /// 원장 종류 중 보호자에게 보이는 것. 예약(RESERVE)·반환(RELEASE)은 정산 때 사용 줄로 합쳐지고, 초과(OVERAGE)는 증감이 0 이다
  private static final List<CreditLedgerType> VISIBLE_TYPES = List.of(
    CreditLedgerType.CONSUME, CreditLedgerType.GRANT, CreditLedgerType.EXPIRE, CreditLedgerType.ADJUST
  );

  private final AiCreditLedgerRepository ledgerRepository;
  private final AiCreditJobRepository jobRepository;
  private final AiCreditGrantRepository grantRepository;
  private final RoutineQueryService routineQueryService;
  private final CreditAccountService accountService;
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 빠뜨리면 서버가 뜨지 않는다.
  @Autowired
  public CreditHistoryService(
    AiCreditLedgerRepository ledgerRepository, AiCreditJobRepository jobRepository,
    AiCreditGrantRepository grantRepository, RoutineQueryService routineQueryService,
    CreditAccountService accountService
  ) {
    this(ledgerRepository, jobRepository, grantRepository, routineQueryService, accountService,
      Clock.systemDefaultZone());
  }

  CreditHistoryService(
    AiCreditLedgerRepository ledgerRepository, AiCreditJobRepository jobRepository,
    AiCreditGrantRepository grantRepository, RoutineQueryService routineQueryService,
    CreditAccountService accountService, Clock clock
  ) {
    this.ledgerRepository = ledgerRepository;
    this.jobRepository = jobRepository;
    this.grantRepository = grantRepository;
    this.routineQueryService = routineQueryService;
    this.accountService = accountService;
    this.clock = clock;
  }

  /**
   * 내 내역 한 쪽. 계정이 아직 없으면 빈 쪽이다 (조회로 계정을 만들지 않는다).
   */
  @Transactional(readOnly = true)
  public CreditHistoryResponse getMine(String memberId, int page, int size) {
    int safePage = Math.max(page, 0);
    int safeSize = Math.min(Math.max(size, 1), MAX_PAGE_SIZE);

    // 본인 계정만 (계정 없음이면 빈 쪽)
    var account = accountService.findAccount(memberId);
    if (account.isEmpty()) {
      return CreditHistoryResponse.empty(safePage);
    }

    Slice<AiCreditLedger> slice = ledgerRepository.findByAccountIdAndTypeInOrderByCreatedAtDescIdDesc(
      account.get().getId(), VISIBLE_TYPES, PageRequest.of(safePage, safeSize));
    List<AiCreditLedger> lines = slice.getContent();

    // 줄마다 따로 조회하지 않고 작업·적립·일과를 한 번씩 모은다
    Lookup lookup = loadLookup(lines);
    List<Entry> entries = new ArrayList<>();
    for (AiCreditLedger line : lines) {
      entries.addAll(toEntries(line, lookup));
    }
    return new CreditHistoryResponse(entries, slice.hasNext(), safePage);
  }

  private Lookup loadLookup(List<AiCreditLedger> lines) {
    Set<String> jobIds = idsOf(lines, AiCreditLedger::getJobId);
    Set<String> grantIds = idsOf(lines, AiCreditLedger::getGrantId);

    Map<String, AiCreditJob> jobById = jobIds.isEmpty() ? Map.of()
      : jobRepository.findAllById(jobIds).stream().collect(Collectors.toMap(AiCreditJob::getId, Function.identity()));
    Map<String, AiCreditGrant> grantById = grantIds.isEmpty() ? Map.of()
      : grantRepository.findAllById(grantIds).stream()
        .collect(Collectors.toMap(AiCreditGrant::getId, Function.identity()));

    Set<String> routineIds = jobById.values().stream()
      .map(AiCreditJob::getRoutineId).filter(Objects::nonNull).collect(Collectors.toSet());
    // 지워진 일과는 조회되지 않는다 > 제목 없음으로 보인다
    Map<String, String> titleByRoutineId = routineQueryService.findTitlesByIds(routineIds);
    return new Lookup(jobById, grantById, titleByRoutineId);
  }

  private static Set<String> idsOf(Collection<AiCreditLedger> lines, Function<AiCreditLedger, String> idOf) {
    Set<String> ids = new HashSet<>();
    for (AiCreditLedger line : lines) {
      String id = idOf.apply(line);
      if (id != null) {
        ids.add(id);
      }
    }
    return ids;
  }

  /// 원장 한 줄 > 보이는 줄 0~2개 (일과 사용은 글·그림 두 줄로 나뉜다)
  private List<Entry> toEntries(AiCreditLedger line, Lookup lookup) {
    if (line.getDelta() == 0) {
      return List.of();
    }
    return switch (line.getType()) {
      case CONSUME -> consumeEntries(line, lookup);
      case GRANT -> List.of(entry(line.getId(), grantKind(line, lookup), null, null, line.getDelta(),
        line.getCreatedAt()));
      case EXPIRE -> List.of(entry(line.getId(), CreditHistoryKind.EXPIRED, null, null, line.getDelta(),
        line.getCreatedAt()));
      case ADJUST -> List.of(entry(line.getId(), CreditHistoryKind.ADJUSTED, null, null, line.getDelta(),
        line.getCreatedAt()));
      default -> List.of();
    };
  }

  private static CreditHistoryKind grantKind(AiCreditLedger line, Lookup lookup) {
    AiCreditGrant grant = line.getGrantId() == null ? null : lookup.grantById().get(line.getGrantId());
    CreditGrantSource source = grant == null ? null : grant.getSource();
    if (source == null) {
      return CreditHistoryKind.OTHER_GRANT;
    }
    return switch (source) {
      case WEEKLY -> CreditHistoryKind.WEEKLY_GRANT;
      case AD_REWARD -> CreditHistoryKind.AD_REWARD;
      case ADMIN_BONUS -> CreditHistoryKind.ADMIN_BONUS;
      default -> CreditHistoryKind.OTHER_GRANT;
    };
  }

  /**
   * 사용 줄. 일과 생성은 정산이 한 줄로 차감하므로 시작 때 단가로 글 몫과 그림 몫을 나눠 두 줄로 보인다
   * (잔액이 모자라 덜 차감됐으면 글 몫을 먼저 채운다)
   */
  private List<Entry> consumeEntries(AiCreditLedger line, Lookup lookup) {
    int charged = -line.getDelta();
    AiCreditJob job = line.getJobId() == null ? null : lookup.jobById().get(line.getJobId());
    String title = job == null || job.getRoutineId() == null ? null : lookup.titleByRoutineId().get(job.getRoutineId());
    LocalDateTime settledAt = line.getCreatedAt();

    CreditJobKind jobKind = job == null ? null : job.getKind();
    if (jobKind == CreditJobKind.ROUTINE_CREATE) {
      int textCost = AiCreditPolicy.costFrom(job.getCostSnapshot(), CreditAction.ROUTINE_TEXT);
      int textPart = Math.min(charged, textCost);
      int imagePart = charged - textPart;
      // 그림이 없었는데 남는 몫이 있으면(단가가 어긋난 옛 기록) 글 한 줄에 합친다
      if (job.getImageCount() <= 0) {
        textPart = charged;
        imagePart = 0;
      }
      List<Entry> entries = new ArrayList<>();
      // 같은 정산이라 그림 줄이 위(나중 시각), 글 줄이 아래(시작 시각)다
      if (imagePart > 0) {
        entries.add(entry(line.getId() + ":image", CreditHistoryKind.CARD_IMAGES, title, job.getImageCount(),
          -imagePart, settledAt));
      }
      if (textPart > 0) {
        LocalDateTime startedAt = job.getStartedAt() == null ? settledAt : job.getStartedAt();
        entries.add(entry(line.getId() + ":text", CreditHistoryKind.ROUTINE_TEXT, title, null, -textPart,
          startedAt));
      }
      return entries;
    }

    CreditHistoryKind kind = switch (jobKind == null ? actionKind(line.getAction()) : jobKind) {
      case CARD_IMAGE -> CreditHistoryKind.CARD_IMAGE;
      case IMAGE_REGENERATE -> CreditHistoryKind.IMAGE_REGENERATE;
      default -> CreditHistoryKind.ROUTINE_TEXT;
    };
    Integer cardCount = job == null || job.getImageCount() <= 0 ? null : job.getImageCount();
    return List.of(entry(line.getId(), kind, title, cardCount, -charged, settledAt));
  }

  /// 작업이 지워져 종류를 모를 때 원장 줄의 행동으로 짐작한다
  private static CreditJobKind actionKind(CreditAction action) {
    if (action == CreditAction.CARD_IMAGE) {
      return CreditJobKind.CARD_IMAGE;
    }
    if (action == CreditAction.IMAGE_REGENERATE) {
      return CreditJobKind.IMAGE_REGENERATE;
    }
    return CreditJobKind.ROUTINE_CREATE;
  }

  private Entry entry(
    String id, CreditHistoryKind kind, String routineTitle, Integer cardCount, int delta, LocalDateTime occurredAt
  ) {
    return new Entry(id, kind, routineTitle, cardCount, delta, occurredAt,
      occurredAt == null ? null : occurredAt.atZone(clock.getZone()).toOffsetDateTime());
  }

  private record Lookup(
    Map<String, AiCreditJob> jobById, Map<String, AiCreditGrant> grantById, Map<String, String> titleByRoutineId
  ) {

  }
}
