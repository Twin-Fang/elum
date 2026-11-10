package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.core.RoutineCardText;
import com.chuseok22.elumserver.routine.core.RoutineMemoryLine;
import com.chuseok22.elumserver.routine.core.RoutineMemorySafetyFilter;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineMemoryAi;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemory;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * AI 메모 갱신의 DB 쪽 (#1082): 준비(대상 일과 고르기·입력 조립) / 반영(줄 합치기·거르기·저장)
 * AI 호출은 RoutineMemoryBuilder 가 두 트랜잭션 사이에서 함 (호출 동안 커넥션을 잡지 않게)
 */
@Slf4j
@Service
public class RoutineMemoryBuildStore {

  /// 하루 1번 묶어 갱신 (원가 절약)
  static final Duration BUILD_INTERVAL = Duration.ofHours(24);
  /// 하루가 안 지나도 고친 일과가 이만큼 쌓이면 갱신
  static final int EARLY_BUILD_EDITED_COUNT = 5;
  /// 한 번에 AI 에 보내는 고친 일과 최대 수 (입력 토큰 제한)
  static final int MAX_EDITS_PER_BUILD = 6;

  private final RoutineRepository routineRepository;
  private final RoutineMemoryRepository routineMemoryRepository;
  private final EntitlementService entitlementService;
  private final RoutineMemoryRows routineMemoryRows;
  private final Clock clock;

  @Autowired
  public RoutineMemoryBuildStore(
    RoutineRepository routineRepository, RoutineMemoryRepository routineMemoryRepository,
    EntitlementService entitlementService, RoutineMemoryRows routineMemoryRows
  ) {
    this(routineRepository, routineMemoryRepository, entitlementService, routineMemoryRows, Clock.systemDefaultZone());
  }

  RoutineMemoryBuildStore(
    RoutineRepository routineRepository, RoutineMemoryRepository routineMemoryRepository,
    EntitlementService entitlementService, RoutineMemoryRows routineMemoryRows, Clock clock
  ) {
    this.routineRepository = routineRepository;
    this.routineMemoryRepository = routineMemoryRepository;
    this.entitlementService = entitlementService;
    this.routineMemoryRows = routineMemoryRows;
    this.clock = clock;
  }

  /**
   * 갱신 작업 하나
   *
   * @param pendingRoutineIds 이번에 반영 처리할 일과 (AI 성공 시 반영 표시)
   * @param input             AI 입력 (원문·이름 없음)
   * @param memberId          호출 기록에 달 보호자 (가장 최근 일과를 만든 사람)
   * @param locale            이름 자리표시 언어
   */
  public record BuildJob(
    String profileId, List<String> pendingRoutineIds, RoutineMemoryAi.MemoryInput input, String memberId,
    AppLocale locale, String nickname
  ) {

  }

  /// 메모 갱신을 기다리는 이룸이 id
  @Transactional(readOnly = true)
  public List<String> findPendingProfileIds() {
    return routineRepository.findProfileIdsWithPendingMemoryEdits(RoutinePersonalizationProvider.CONFIRMED_STATUSES);
  }

  /**
   * 준비: 꺼짐·Pro 아님·고친 것 없음 > 반영 표시만 하고 null / 하루 안 지남 > 그대로 두고 null / 그 외 > 작업
   * 끄면 배우지 않음 — 꺼 둔 동안 확정한 일과는 나중에 켜도 반영하지 않음
   */
  @Transactional
  public BuildJob prepare(String profileId) {
    List<Routine> pending = routineRepository
      .findAllByProfileIdAndAiDraftCardsIsNotNullAndMemoryReflectedAtIsNullAndStatusInOrderByCreatedAtDesc(
        profileId, RoutinePersonalizationProvider.CONFIRMED_STATUSES);
    if (pending.isEmpty()) {
      return null;
    }
    LocalDateTime now = LocalDateTime.now(clock);
    RoutineMemory memory = routineMemoryRepository.findByProfileId(profileId).orElse(null);
    if (memory != null && !memory.isEnabled()) {
      markReflected(pending, now);
      return null;
    }

    // Pro(ROUTINE_MEMORY) 보호자가 만든 일과만 배움. 구독이 끝난 보호자 것은 반영 표시만
    List<Routine> learnable = new ArrayList<>();
    List<Routine> skipped = new ArrayList<>();
    for (Routine routine : pending) {
      boolean isEditedByProGuardian = entitlementService.isAllowed(routine.getCreatedBy(), Entitlement.ROUTINE_MEMORY)
        && isEdited(routine);
      (isEditedByProGuardian ? learnable : skipped).add(routine);
    }
    markReflected(skipped, now);
    if (learnable.isEmpty()) {
      return null;
    }
    if (!isBuildDue(memory, learnable.size(), now)) {
      return null;
    }

    Routine latest = learnable.get(0);
    Profile profile = latest.getProfile();
    AppLocale locale = latest.getLanguage() == null ? AppLocale.KO : latest.getLanguage();
    List<RoutineMemoryLine> lines = memory == null ? List.of() : RoutineMemoryJson.readLines(memory.getLines());
    List<String> dismissed = memory == null ? List.of() : RoutineMemoryJson.readTexts(memory.getDismissedLines());
    int guardianLineCount = (int) lines.stream().filter(line -> line.source() == RoutineMemoryLine.Source.GUARDIAN).count();
    RoutineMemoryAi.MemoryInput input = RoutineMemoryAi.MemoryInput.of(
      learnable.stream().limit(MAX_EDITS_PER_BUILD).map(routine -> toEdit(routine, profile.getNickname(), locale)).toList(),
      textsOf(lines, RoutineMemoryLine.Source.AI),
      textsOf(lines, RoutineMemoryLine.Source.GUARDIAN),
      dismissed,
      Math.max(0, RoutineMemoryLine.MAX_LINES - guardianLineCount));
    return new BuildJob(profileId, learnable.stream().map(Routine::getId).toList(), input, latest.getCreatedBy(),
      locale, profile.getNickname());
  }

  /// 반영: 보호자 줄 유지 > 새 AI 줄 거르기(금지 낱말·기관 이름·보호자 줄과 같음·지운 줄) > 입력의 maxLines 로 자름 > 저장 > 일과 반영 표시
  @Transactional
  public List<RoutineMemoryLine> apply(BuildJob job, List<String> newAiLines) {
    LocalDateTime now = LocalDateTime.now(clock);
    RoutineMemory memory = routineMemoryRows.findOrCreate(job.profileId());
    List<RoutineMemoryLine> guardianLines = RoutineMemoryJson.readLines(memory.getLines()).stream()
      .filter(line -> line.source() == RoutineMemoryLine.Source.GUARDIAN)
      .toList();
    Set<String> blocked = new HashSet<>(RoutineMemoryJson.readTexts(memory.getDismissedLines()));
    guardianLines.forEach(line -> blocked.add(line.text()));

    List<RoutineMemoryLine> merged = new ArrayList<>(guardianLines);
    int maxMergedLineCount = Math.min(RoutineMemoryLine.MAX_LINES, guardianLines.size() + job.input().maxLines());
    int droppedCount = 0;
    for (String rawLine : newAiLines) {
      String line = NicknamePlaceholder.restore(rawLine.trim(), job.nickname(), job.locale());
      if (merged.size() >= maxMergedLineCount) {
        break;
      }
      String rejection = RoutineMemorySafetyFilter.rejectionReason(line);
      if (rejection != null || blocked.contains(line)) {
        droppedCount++;
        log.info("[routine memory] line dropped : profileId={}, reason={}", job.profileId(),
          rejection != null ? rejection : "dismissed or duplicate");
        continue;
      }
      blocked.add(line);
      merged.add(new RoutineMemoryLine(line, RoutineMemoryLine.Source.AI));
    }
    memory.setLines(RoutineMemoryJson.writeLines(merged));
    memory.setLastBuiltAt(now);
    markReflected(routineRepository.findAllById(job.pendingRoutineIds()), now);
    log.info("[routine memory] built : profileId={}, edits={}, lines={}, dropped={}",
      job.profileId(), job.pendingRoutineIds().size(), merged.size(), droppedCount);
    return merged;
  }

  /// AI 실패: 일과는 반영하지 않고 남김, 갱신 시각만 남겨 하루 뒤 다시 (실패가 매 주기 호출로 번지지 않게)
  @Transactional
  public void recordFailure(String profileId) {
    routineMemoryRows.findOrCreate(profileId).setLastBuiltAt(LocalDateTime.now(clock));
  }

  /// 처음 만들거나 하루 지났거나 고친 일과가 5개 이상 쌓였는가
  static boolean isBuildDue(RoutineMemory memory, int editedCount, LocalDateTime now) {
    if (memory == null || memory.getLastBuiltAt() == null) {
      return true;
    }
    if (editedCount >= EARLY_BUILD_EDITED_COUNT) {
      return true;
    }
    return !memory.getLastBuiltAt().plus(BUILD_INTERVAL).isAfter(now);
  }

  private static boolean isEdited(Routine routine) {
    return !routine.getSteps().isEmpty() && RoutineCardText.isEdited(
      RoutineMemoryJson.readCards(routine.getAiDraftCards()), RoutineMemoryJson.cardsOf(routine.getSteps()));
  }

  private static RoutineMemoryAi.RoutineEdit toEdit(Routine routine, String nickname, AppLocale locale) {
    List<String> aiCards = RoutineMemoryJson.readCards(routine.getAiDraftCards()).stream()
      .map(card -> NicknamePlaceholder.mask(card.toPromptLine(), nickname, locale)).toList();
    List<String> confirmedCards = RoutineMemoryJson.cardsOf(routine.getSteps()).stream()
      .map(card -> NicknamePlaceholder.mask(card.toPromptLine(), nickname, locale)).toList();
    int photoCardCount = (int) routine.getSteps().stream()
      .map(RoutineStep::getImagePath)
      .filter(RoutineImageStorage::isGuardianUploadedPhoto)
      .count();
    return new RoutineMemoryAi.RoutineEdit(
      NicknamePlaceholder.mask(routine.getTitle(), nickname, locale), aiCards, confirmedCards, photoCardCount);
  }

  private static List<String> textsOf(List<RoutineMemoryLine> lines, RoutineMemoryLine.Source source) {
    return lines.stream().filter(line -> line.source() == source).map(RoutineMemoryLine::text).toList();
  }

  private static void markReflected(List<Routine> routines, LocalDateTime now) {
    routines.forEach(routine -> routine.setMemoryReflectedAt(now));
  }
}
