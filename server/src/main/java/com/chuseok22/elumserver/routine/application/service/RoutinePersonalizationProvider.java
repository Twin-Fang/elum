package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.ai.core.RoutinePersonalization;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.routine.core.RoutineCardText;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleSource;
import com.chuseok22.elumserver.routine.core.RoutineMemoryRuleStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemoryRule;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRuleRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.Comparator;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 일과 만들기 맞춤 정보 준비: Pro·켜짐 확인 > 만드는 보호자 자신의 적용 중(ACTIVE) 규칙 최대 10개 > 그 보호자가 고쳐 확정한 예시(최대 3개) > 이름 자리표시
 * 다른 보호자의 규칙·일과는 쓰지 않음. 실패하면 빈 계획(지금 하네스 그대로) — 일과 만들기를 막지 않음
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutinePersonalizationProvider {

  /// 프롬프트에 넣는 확정 예시 최대 수 (입력 토큰 약 150 x 3)
  static final int MAX_EXAMPLES = 3;
  /// 확정·완료 일과만 예시가 됨 (임시저장은 보호자가 아직 확정하지 않음)
  static final List<RoutineStatus> CONFIRMED_STATUSES = RoutineMemoryExtractionStore.CONFIRMED_STATUSES;

  private final EntitlementService entitlementService;
  private final RoutineMemorySettings routineMemorySettings;
  private final RoutineMemoryRuleRepository routineMemoryRuleRepository;
  private final RoutineRepository routineRepository;

  /**
   * @param isMemoryActive   Pro + 켜짐. true 면 이번 일과의 AI 처음 카드를 사본으로 남김
   * @param personalization  요청에 실을 맞춤 정보. 규칙·예시가 없으면 null
   * @param appliedRuleCount 넣은 규칙 수 (응답 appliedMemoryRuleCount)
   */
  public record Plan(boolean isMemoryActive, RoutinePersonalization personalization, int appliedRuleCount) {

    static final Plan INACTIVE = new Plan(false, null, 0);
  }

  /// 이 보호자가 이 이룸이로 일과를 만들 때의 계획 (던지지 않음)
  public Plan planFor(String memberId, String profileId, String nickname, AppLocale locale) {
    try {
      if (!isMemoryActive(memberId, profileId)) {
        return Plan.INACTIVE;
      }
      List<String> notes = appliedRuleNotesOf(profileId, memberId, nickname, locale);
      List<RoutinePersonalization.ConfirmedExample> examples = confirmedExamplesOf(profileId, memberId, nickname, locale);
      RoutinePersonalization personalization = RoutinePersonalization.of(notes, examples);
      log.info("[routine memory] personalization planned : profileId={}, rules={}, examples={}",
        profileId, notes.size(), examples.size());
      return new Plan(true, personalization.isEmpty() ? null : personalization, notes.size());
    } catch (RuntimeException e) {
      log.warn("[routine memory] personalization failed, using default harness : profileId={}", profileId, e);
      return Plan.INACTIVE;
    }
  }

  /// Pro(ROUTINE_MEMORY) 이고 이 (이룸이, 보호자) 메모리가 꺼져 있지 않은가 (설정 없으면 켜짐)
  boolean isMemoryActive(String memberId, String profileId) {
    if (memberId == null || !entitlementService.isAllowed(memberId, Entitlement.ROUTINE_MEMORY)) {
      return false;
    }
    return routineMemorySettings.isEnabled(profileId, memberId);
  }

  /// 적용 중 규칙만, 직접 적은 것 먼저 > 근거 많은 순 > 최근 것, 최대 10개
  private List<String> appliedRuleNotesOf(String profileId, String memberId, String nickname, AppLocale locale) {
    return routineMemoryRuleRepository
      .findAllByProfileIdAndMemberIdAndStatus(profileId, memberId, RoutineMemoryRuleStatus.ACTIVE).stream()
      .sorted(Comparator.comparing((RoutineMemoryRule rule) -> rule.getSource() != RoutineMemoryRuleSource.MANUAL)
        .thenComparing(Comparator.comparingInt(RoutineMemoryRule::getEvidenceCount).reversed())
        .thenComparing(RoutineMemoryRule::getUpdatedAt, Comparator.nullsLast(Comparator.reverseOrder())))
      .limit(RoutineMemoryPolicy.MAX_APPLIED_RULES)
      .map(rule -> NicknamePlaceholder.mask(rule.getSummary(), nickname, locale))
      .toList();
  }

  /// 그 보호자가 고쳐 확정한 최근 일과 최대 3개 (고치지 않은 일과는 예시로 쓰지 않음)
  private List<RoutinePersonalization.ConfirmedExample> confirmedExamplesOf(
    String profileId, String memberId, String nickname, AppLocale locale
  ) {
    return routineRepository
      .findTop10ByProfileIdAndCreatedByAndAiDraftCardsIsNotNullAndStatusInOrderByCreatedAtDesc(
        profileId, memberId, CONFIRMED_STATUSES).stream()
      .filter(RoutinePersonalizationProvider::isEditedByGuardian)
      .limit(MAX_EXAMPLES)
      .map(routine -> toExample(routine, nickname, locale))
      .toList();
  }

  private static boolean isEditedByGuardian(Routine routine) {
    return !routine.getSteps().isEmpty() && RoutineCardText.isEdited(
      RoutineMemoryJson.readCards(routine.getAiDraftCards()), RoutineMemoryJson.cardsOf(routine.getSteps()));
  }

  private RoutinePersonalization.ConfirmedExample toExample(Routine routine, String nickname, AppLocale locale) {
    List<String> cards = RoutineMemoryJson.cardsOf(routine.getSteps()).stream()
      .map(card -> NicknamePlaceholder.mask(card.toPromptLine(), nickname, locale))
      .toList();
    return new RoutinePersonalization.ConfirmedExample(
      NicknamePlaceholder.mask(routine.getTitle(), nickname, locale), cards);
  }
}
