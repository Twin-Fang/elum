package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.infrastructure.client.SupertonicTtsClient;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.core.RoutineStepSpeechText;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository.SpeechTextSource;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineStepSpeechStorage;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 단계 음성 1건 채우기: 단계 확인 > 문장 > 합성 > 저장 > 문장 재확인 > 열쇠 갱신 (#675)
 * 어떤 실패도 밖으로 던지지 않음 (열쇠 null 유지 > 주기 작업이 다시 시도, 앱은 기기 음성)
 * 반환: 합성 실패면 false (대기열이 잠시 쉬었다 다시 시도), 그 외(저장·건너뜀·폐기)는 true
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineStepSpeechFiller {

  private final SupertonicTtsClient supertonicTtsClient;
  private final RoutineStepSpeechStorage routineStepSpeechStorage;
  private final RoutineStepRepository routineStepRepository;

  public boolean fill(String stepId) {
    try {
      // 단계 확인 (지워졌거나 한국어 아닌 일과면 건너뜀)
      Optional<String> text = speechTextOf(stepId);
      if (text.isEmpty()) {
        return true;
      }
      String textHash = RoutineStepSpeechText.hashOf(text.get());

      // 합성 > 저장
      long startedAt = System.currentTimeMillis();
      byte[] wav = supertonicTtsClient.synthesize(text.get());
      String speechKey = routineStepSpeechStorage.save(stepId, textHash, wav);

      // 합성 중 글이 바뀌었으면 버림 (새 글은 이미 다시 예약됨)
      if (!isSameText(stepId, textHash)) {
        routineStepSpeechStorage.delete(speechKey);
        log.info("[routine speech] discarded stale : stepId={}", stepId);
        return true;
      }
      // 열쇠 갱신, 0 이면 그새 단계 삭제 > 파일 정리
      if (routineStepRepository.updateSpeechPath(stepId, speechKey) == 0) {
        routineStepSpeechStorage.delete(speechKey);
        log.info("[routine speech] discarded deleted step : stepId={}", stepId);
        return true;
      }
      log.info("[routine speech] saved : stepId={}, bytes={}, elapsedMs={}",
        stepId, wav.length, System.currentTimeMillis() - startedAt);
      return true;
    } catch (Exception e) {
      log.warn("[routine speech] failed : stepId={}, cause={}: {}",
        stepId, e.getClass().getSimpleName(), e.getMessage());
      return false;
    }
  }

  /**
   * 단계 > 읽을 문장. 단계 없음, 한국어 아님, 빈 설명이면 빈 값
   */
  private Optional<String> speechTextOf(String stepId) {
    Optional<SpeechTextSource> source = routineStepRepository.findSpeechTextSource(stepId);
    if (source.isEmpty() || !isKorean(source.get().getLanguage())) {
      return Optional.empty();
    }
    String description = source.get().getDescription();
    if (description == null || description.isBlank()) {
      return Optional.empty();
    }
    return Optional.of(RoutineStepSpeechText.of(source.get().getTitle(), description));
  }

  private boolean isSameText(String stepId, String textHash) {
    return speechTextOf(stepId)
      .map(RoutineStepSpeechText::hashOf)
      .filter(textHash::equals)
      .isPresent();
  }

  /// Supertonic F1 은 한국어 목소리 (다른 언어는 기기 음성)
  private static boolean isKorean(AppLocale language) {
    return language == null || language == AppLocale.KO;
  }
}
