package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.routine.core.RoutineCardText;
import com.chuseok22.elumserver.routine.core.RoutineMemoryExtractionState;
import com.chuseok22.elumserver.routine.core.RoutineMemoryFinding;
import com.chuseok22.elumserver.routine.core.RoutineMemoryFindingValidator;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleSource;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleType;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineMemoryAi;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryEdit;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryEvidence;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRule;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryEditRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryEvidenceRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRejectionRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRuleRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 수정 찾기의 DB 쪽: 선점(대상 확인·수정 기록·AI 입력 조립) / 반영(검증 > 기존 규칙에 근거 더하기·새 규칙 > 횟수 닿으면 적용)
 * AI 호출은 RoutineMemoryExtractor 가 두 트랜잭션 사이에서 함 (호출 동안 커넥션을 잡지 않게). 횟수 세기·적용·중복 방지는 여기서만
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RoutineMemoryExtractionStore {

  /// 확정·완료 일과만 찾음 (임시저장은 보호자가 아직 확정하지 않음)
  static final List<RoutineStatus> CONFIRMED_STATUSES = List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED);
  /// 한 일과에서 받아들이는 새 수정 최대 수
  static final int MAX_FOUND_PER_ROUTINE = 5;
  /// 놓친 일과를 줍는 기준: 마지막 수정이 이만큼 지났고 이 기간 안이며 한 번에 이만큼만
  static final Duration MISSED_SETTLE_DELAY = Duration.ofMinutes(15);
  static final Duration MISSED_LOOKBACK = Duration.ofDays(3);
  static final int MAX_MISSED_PER_RUN = 20;

  private final RoutineRepository routineRepository;
  private final EntitlementService entitlementService;
  private final RoutineMemorySettings routineMemorySettings;
  private final RoutineMemoryRuleRepository routineMemoryRuleRepository;
  private final RoutineMemoryEvidenceRepository routineMemoryEvidenceRepository;
  private final RoutineMemoryEditRepository routineMemoryEditRepository;
  private final RoutineMemoryRejectionRepository routineMemoryRejectionRepository;
  private final RoutineMemoryPolicy routineMemoryPolicy;

  /**
   * 찾기 작업 하나
   *
   * @param firstCards     자리표시로 바꾼 처음 카드 (검증도 이 글로 함)
   * @param confirmedCards 자리표시로 바꾼 확정 카드
   */
  public record ExtractionJob(
    String routineId, String routineTitle, String profileId, String memberId, AppLocale locale,
    List<RoutineCardText> firstCards, List<RoutineCardText> confirmedCards, RoutineMemoryAi.ExtractionInput input
  ) {

  }

  /// 반영 결과 개수 (로그용): 기존 규칙에 짝지음 / 새 규칙 / 버림
  public record ApplyResult(int matchedCount, int createdCount, int droppedCount) {

  }

  /// 놓친 일과 id (안정된 확정 일과 중 아직 아무도 선점하지 않은 것)
  @Transactional(readOnly = true)
  public List<String> findMissedRoutineIds() {
    LocalDateTime now = LocalDateTime.now();
    return routineRepository.findIdsMissedByMemoryExtraction(CONFIRMED_STATUSES, now.minus(MISSED_SETTLE_DELAY),
      now.minus(MISSED_LOOKBACK), PageRequest.of(0, MAX_MISSED_PER_RUN));
  }

  /**
   * 선점: 확정·처음 카드 있음 > 한 번만(반영 표시 선점) > Pro·켜짐·고친 것 있음 > 수정 기록(PENDING) 저장 > AI 입력
   * 대상이 아니면 반영 표시만 하고 빈 값 (같은 일과를 다시 보지 않음)
   */
  @Transactional
  public Optional<ExtractionJob> claim(String routineId) {
    Routine routine = routineRepository.findById(routineId).orElse(null);
    boolean isCandidate = routine != null && CONFIRMED_STATUSES.contains(routine.getStatus())
      && routine.getAiDraftCards() != null && routine.getCreatedBy() != null && routine.getProfile() != null;
    if (!isCandidate || routineRepository.claimMemoryExtraction(routineId, LocalDateTime.now()) != 1) {
      return Optional.empty();
    }
    String memberId = routine.getCreatedBy();
    String profileId = routine.getProfile().getId();
    List<RoutineCardText> firstCards = RoutineMemoryJson.readCards(routine.getAiDraftCards());
    List<RoutineCardText> confirmedCards = RoutineMemoryJson.cardsOf(routine.getSteps());
    boolean isEligible = entitlementService.isAllowed(memberId, Entitlement.ROUTINE_MEMORY)
      && routineMemorySettings.isEnabled(profileId, memberId)
      && !routine.getSteps().isEmpty() && RoutineCardText.isEdited(firstCards, confirmedCards);
    if (!isEligible) {
      log.info("[routine memory] extraction skipped : routineId={}, reason=not eligible", routineId);
      return Optional.empty();
    }
    saveEdit(routine, firstCards, confirmedCards);
    AppLocale locale = routine.getLanguage() == null ? AppLocale.KO : routine.getLanguage();
    String nickname = routine.getProfile().getNickname();
    List<RoutineCardText> maskedFirst = maskAll(firstCards, nickname, locale);
    List<RoutineCardText> maskedConfirmed = maskAll(confirmedCards, nickname, locale);
    RoutineMemoryAi.ExtractionInput input = RoutineMemoryAi.ExtractionInput.of(
      maskedFirst.stream().map(RoutineCardText::toPromptLine).toList(),
      maskedConfirmed.stream().map(RoutineCardText::toPromptLine).toList(),
      existingRulesForAi(profileId, memberId), rejectedRulesForAi(profileId, memberId));
    return Optional.of(new ExtractionJob(routineId, routine.getTitle(), profileId, memberId, locale, maskedFirst,
      maskedConfirmed, input));
  }

  /// 반영: AI 가 짝지은 기존 규칙·새로 찾은 수정을 서버가 검증해 근거로 셈. 횟수에 닿으면 관찰 중 > 적용. 수정 기록은 DONE
  @Transactional
  public ApplyResult apply(ExtractionJob job, RoutineMemoryAi.ExtractionResult result) {
    List<RoutineMemoryRule> ownedRules = routineMemoryRuleRepository.findAllByProfileIdAndMemberId(
      job.profileId(), job.memberId());
    Map<String, RoutineMemoryRule> ruleById = new HashMap<>();
    Map<String, RoutineMemoryRule> ruleByKey = new HashMap<>();
    for (RoutineMemoryRule rule : ownedRules) {
      ruleById.put(rule.getId(), rule);
      if (rule.getType() != RoutineMemoryRuleType.MANUAL) {
        ruleByKey.putIfAbsent(
          RoutineMemoryFinding.identityKeyOf(rule.getType(), rule.getBeforeText(), rule.getAfterText()), rule);
      }
    }
    Set<String> rejectedKeys = new HashSet<>();
    routineMemoryRejectionRepository.findAllByProfileIdAndMemberId(job.profileId(), job.memberId()).forEach(
      rejection -> rejectedKeys.add(
        RoutineMemoryFinding.identityKeyOf(rejection.getType(), rejection.getBeforeText(), rejection.getAfterText())));
    Set<String> countedRuleIds = new HashSet<>();
    int matchedCount = 0;
    int createdCount = 0;
    int droppedCount = 0;
    int ruleCount = ownedRules.size();

    // AI 가 짝지은 기존 규칙 (이 보호자의 규칙이고 이번 카드에 그 수정이 실제로 있을 때만)
    for (String ruleId : result.matchedRuleIds().stream().distinct().toList()) {
      RoutineMemoryRule rule = ruleById.get(ruleId);
      boolean isValidMatch = rule != null && rule.getType() != RoutineMemoryRuleType.MANUAL
        && RoutineMemoryFindingValidator.isSupportedByCards(rule.getType(), rule.getBeforeText(), rule.getAfterText(),
        job.firstCards(), job.confirmedCards());
      if (!isValidMatch) {
        droppedCount++;
        log.info("[routine memory] matched dropped : routineId={}, reason={}", job.routineId(),
          rule == null ? "unknown rule id" : "not in cards");
        continue;
      }
      matchedCount += countEvidence(rule, job, countedRuleIds) ? 1 : 0;
    }

    // 새로 찾은 수정 (최대 5개): 검증 > 거절 기억 > 같은 수정의 기존 규칙이면 근거만 > 아니면 관찰 중 규칙 만들기
    for (RoutineMemoryFinding raw : result.foundFindings().stream().limit(MAX_FOUND_PER_ROUTINE).toList()) {
      RoutineMemoryFinding finding = RoutineMemoryFindingValidator.normalize(raw);
      String reason = RoutineMemoryFindingValidator.rejectionReason(finding, job.firstCards(), job.confirmedCards(),
        List.of(NicknamePlaceholder.PLACEHOLDER, NicknamePlaceholder.GLOBAL_PLACEHOLDER));
      String key = finding.identityKey();
      RoutineMemoryRule existing = ruleByKey.get(key);
      if (reason == null && rejectedKeys.contains(key)) {
        reason = "rejected before";
      }
      if (reason == null && existing == null && ruleCount >= RoutineMemoryPolicy.MAX_RULES_PER_OWNER) {
        reason = "rule limit";
      }
      if (reason != null) {
        droppedCount++;
        log.info("[routine memory] found dropped : routineId={}, reason={}", job.routineId(), reason);
        continue;
      }
      RoutineMemoryRule rule = existing != null ? existing : createWatchingRule(job, finding);
      if (existing == null) {
        ruleByKey.put(key, rule);
        ruleCount++;
        createdCount++;
      }
      countEvidence(rule, job, countedRuleIds);
    }
    markEditState(job.routineId(), RoutineMemoryExtractionState.DONE);
    log.info("[routine memory] extraction applied : routineId={}, matched={}, created={}, dropped={}", job.routineId(),
      matchedCount, createdCount, droppedCount);
    return new ApplyResult(matchedCount, createdCount, droppedCount);
  }

  /// AI 실패·예외: 수정 기록은 남기고 상태만 FAILED (같은 일과를 다시 찾지 않음)
  @Transactional
  public void markFailed(String routineId) {
    markEditState(routineId, RoutineMemoryExtractionState.FAILED);
  }

  /// 일과 하나는 규칙마다 한 번만 셈 (근거 표 유일). 센 경우 true. 횟수에 닿고 관찰 중이면 적용, 끈 규칙(OFF)은 그대로
  private boolean countEvidence(RoutineMemoryRule rule, ExtractionJob job, Set<String> countedRuleIds) {
    boolean isFirstTimeInJob = countedRuleIds.add(rule.getId());
    if (!isFirstTimeInJob || routineMemoryEvidenceRepository.existsByRuleIdAndRoutineId(rule.getId(), job.routineId())) {
      return false;
    }
    RoutineMemoryEvidence evidence = new RoutineMemoryEvidence();
    evidence.setRuleId(rule.getId());
    evidence.setRoutineId(job.routineId());
    evidence.setRoutineTitle(job.routineTitle());
    evidence.setObservedAt(LocalDateTime.now());
    routineMemoryEvidenceRepository.save(evidence);
    rule.setEvidenceCount(rule.getEvidenceCount() + 1);
    boolean isReadyToApply = rule.getStatus() == RoutineMemoryRuleStatus.WATCHING
      && rule.getEvidenceCount() >= routineMemoryPolicy.autoApplyCount();
    if (isReadyToApply) {
      rule.setStatus(RoutineMemoryRuleStatus.ACTIVE);
      log.info("[routine memory] rule auto applied : profileId={}, type={}, evidenceCount={}", job.profileId(),
        rule.getType(), rule.getEvidenceCount());
    }
    return true;
  }

  private RoutineMemoryRule createWatchingRule(ExtractionJob job, RoutineMemoryFinding finding) {
    RoutineMemoryRule rule = new RoutineMemoryRule();
    rule.setProfileId(job.profileId());
    rule.setMemberId(job.memberId());
    rule.setType(finding.type());
    rule.setStatus(RoutineMemoryRuleStatus.WATCHING);
    rule.setSource(RoutineMemoryRuleSource.AI);
    rule.setSummary(RoutineMemoryFindingValidator.summaryOf(finding));
    rule.setBeforeText(finding.before());
    rule.setAfterText(finding.after());
    return routineMemoryRuleRepository.save(rule);
  }

  /// 수정 기록 한 줄 (AI 없이 셈): 카드 수 전·후 + 확정 카드 중 처음 카드에 없던 글의 수
  private void saveEdit(Routine routine, List<RoutineCardText> firstCards, List<RoutineCardText> confirmedCards) {
    Set<String> firstLines = new HashSet<>();
    firstCards.forEach(card -> firstLines.add(card.toPromptLine()));
    RoutineMemoryEdit edit = new RoutineMemoryEdit();
    edit.setProfileId(routine.getProfile().getId());
    edit.setMemberId(routine.getCreatedBy());
    edit.setRoutineId(routine.getId());
    edit.setRoutineTitle(routine.getTitle());
    edit.setEditedAt(LocalDateTime.now());
    edit.setCardCountBefore(firstCards.size());
    edit.setCardCountAfter(confirmedCards.size());
    edit.setChangedTextCount((int) confirmedCards.stream().filter(card -> !firstLines.contains(card.toPromptLine())).count());
    edit.setExtractionState(RoutineMemoryExtractionState.PENDING);
    routineMemoryEditRepository.save(edit);
  }

  private void markEditState(String routineId, RoutineMemoryExtractionState state) {
    routineMemoryEditRepository.findByRoutineId(routineId).ifPresent(edit -> edit.setExtractionState(state));
  }

  /// AI 에 보내는 기존 규칙: 직접 적은 규칙 제외, 최근 것 50개
  private List<RoutineMemoryAi.ExistingRule> existingRulesForAi(String profileId, String memberId) {
    return routineMemoryRuleRepository.findAllByProfileIdAndMemberId(profileId, memberId).stream()
      .filter(rule -> rule.getType() != RoutineMemoryRuleType.MANUAL)
      .sorted(Comparator.comparing(RoutineMemoryRule::getUpdatedAt, Comparator.nullsLast(Comparator.reverseOrder())))
      .limit(RoutineMemoryPolicy.MAX_RULES_SENT_TO_AI)
      .map(rule -> new RoutineMemoryAi.ExistingRule(rule.getId(), rule.getType(), rule.getBeforeText(),
        rule.getAfterText(), rule.getSummary()))
      .toList();
  }

  private List<RoutineMemoryAi.RejectedRule> rejectedRulesForAi(String profileId, String memberId) {
    return routineMemoryRejectionRepository.findAllByProfileIdAndMemberId(profileId, memberId).stream()
      .limit(RoutineMemoryPolicy.MAX_RULES_SENT_TO_AI)
      .map(rejection -> new RoutineMemoryAi.RejectedRule(
        rejection.getType(), rejection.getBeforeText(), rejection.getAfterText()))
      .toList();
  }

  private static List<RoutineCardText> maskAll(List<RoutineCardText> cards, String nickname, AppLocale locale) {
    List<RoutineCardText> masked = new ArrayList<>();
    for (RoutineCardText card : cards) {
      masked.add(new RoutineCardText(NicknamePlaceholder.mask(card.title(), nickname, locale),
        NicknamePlaceholder.mask(card.description(), nickname, locale)));
    }
    return masked;
  }
}
