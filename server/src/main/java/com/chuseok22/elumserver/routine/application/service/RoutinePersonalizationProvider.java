package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.ai.core.RoutinePersonalization;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.routine.core.RoutineCardText;
import com.chuseok22.elumserver.routine.core.RoutineMemoryLine;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemory;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 일과 만들기 맞춤 정보 준비 (#1082): Pro·켜짐 확인 > 메모 줄 > 확정 예시(고친 것 먼저, 최대 3개) > 이름 자리표시
 * 실패하면 빈 계획(지금 하네스 그대로) — 일과 만들기를 막지 않음
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutinePersonalizationProvider {

  /// 프롬프트에 넣는 확정 예시 최대 수 (입력 토큰 약 150 x 3)
  static final int MAX_EXAMPLES = 3;
  /// 확정·완료 일과만 예시가 됨 (임시저장은 보호자가 아직 확정하지 않음)
  static final List<RoutineStatus> CONFIRMED_STATUSES = List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED);

  private final EntitlementService entitlementService;
  private final RoutineMemoryRepository routineMemoryRepository;
  private final RoutineRepository routineRepository;

  /**
   * @param isMemoryActive  Pro + 메모 켜짐. true 면 이번 일과의 AI 처음 카드를 스냅샷으로 남김
   * @param personalization 요청에 실을 맞춤 정보. 메모·예시가 없으면 null
   */
  public record Plan(boolean isMemoryActive, RoutinePersonalization personalization) {

    static final Plan INACTIVE = new Plan(false, null);
  }

  /// 이 보호자가 이 이룸이로 일과를 만들 때의 계획 (던지지 않음)
  public Plan planFor(String memberId, String profileId, String nickname, AppLocale locale) {
    try {
      if (!isMemoryActive(memberId, profileId)) {
        return Plan.INACTIVE;
      }
      List<String> notes = memoryNotesOf(profileId, nickname, locale);
      List<RoutinePersonalization.ConfirmedExample> examples = confirmedExamplesOf(profileId, nickname, locale);
      RoutinePersonalization personalization = RoutinePersonalization.of(notes, examples);
      log.info("[routine memory] personalization planned : profileId={}, notes={}, examples={}",
        profileId, notes.size(), examples.size());
      return new Plan(true, personalization.isEmpty() ? null : personalization);
    } catch (RuntimeException e) {
      log.warn("[routine memory] personalization failed, using default harness : profileId={}", profileId, e);
      return Plan.INACTIVE;
    }
  }

  /// Pro(ROUTINE_MEMORY) 이고 이 이룸이 메모가 꺼져 있지 않은가 (행이 없으면 켜짐으로 봄)
  boolean isMemoryActive(String memberId, String profileId) {
    if (memberId == null || !entitlementService.isAllowed(memberId, Entitlement.ROUTINE_MEMORY)) {
      return false;
    }
    return routineMemoryRepository.findByProfileId(profileId).map(RoutineMemory::isEnabled).orElse(true);
  }

  private List<String> memoryNotesOf(String profileId, String nickname, AppLocale locale) {
    Optional<RoutineMemory> memory = routineMemoryRepository.findByProfileId(profileId);
    return memory.map(found -> RoutineMemoryJson.readLines(found.getLines()).stream()
        .map(RoutineMemoryLine::text)
        .map(text -> NicknamePlaceholder.mask(text, nickname, locale))
        .toList())
      .orElse(List.of());
  }

  /// 최근 확정 일과 중 보호자가 고친 것 먼저, 모자라면 고치지 않은 것으로 채움 (최대 3개)
  private List<RoutinePersonalization.ConfirmedExample> confirmedExamplesOf(
    String profileId, String nickname, AppLocale locale
  ) {
    List<Routine> candidates = routineRepository
      .findTop10ByProfileIdAndAiDraftCardsIsNotNullAndStatusInOrderByCreatedAtDesc(profileId, CONFIRMED_STATUSES);
    List<Routine> edited = new ArrayList<>();
    List<Routine> unedited = new ArrayList<>();
    for (Routine routine : candidates) {
      if (routine.getSteps().isEmpty()) {
        continue;
      }
      List<RoutineCardText> aiCards = RoutineMemoryJson.readCards(routine.getAiDraftCards());
      List<RoutineCardText> confirmedCards = RoutineMemoryJson.cardsOf(routine.getSteps());
      (RoutineCardText.isEdited(aiCards, confirmedCards) ? edited : unedited).add(routine);
    }
    List<Routine> picked = new ArrayList<>(edited);
    picked.addAll(unedited);
    return picked.stream()
      .limit(MAX_EXAMPLES)
      .map(routine -> toExample(routine, nickname, locale))
      .toList();
  }

  private RoutinePersonalization.ConfirmedExample toExample(Routine routine, String nickname, AppLocale locale) {
    List<String> cards = RoutineMemoryJson.cardsOf(routine.getSteps()).stream()
      .map(card -> NicknamePlaceholder.mask(card.toPromptLine(), nickname, locale))
      .toList();
    return new RoutinePersonalization.ConfirmedExample(
      NicknamePlaceholder.mask(routine.getTitle(), nickname, locale), cards);
  }
}
