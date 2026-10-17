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
      // 단계 확인 (지워졌거나 한국어 아닌 일과, 빈 설명이면 건너뜀)
      Optional<SpeechTextSource> source = routineStepRepository.findSpeechTextSource(stepId)
        .filter(RoutineStepSpeechFiller::isSpeakable);
      if (source.isEmpty()) {
        return true;
      }
      String title = source.get().getTitle();
      String description = source.get().getDescription();
      String text = RoutineStepSpeechText.of(title, description);

      // 합성 > 저장
      long startedAt = System.currentTimeMillis();
      byte[] wav = supertonicTtsClient.synthesize(text);
      String speechKey = routineStepSpeechStorage.save(stepId, RoutineStepSpeechText.hashOf(text), wav);

      // 열쇠 갱신: 합성에 쓴 글이 지금도 같을 때만 (0 = 그새 글 수정 또는 삭제 > 파일 버림, 새 글은 다시 예약됨)
      if (routineStepRepository.updateSpeechPathIfTextUnchanged(
        stepId, speechKey, title == null ? "" : title, description) == 0) {
        routineStepSpeechStorage.delete(speechKey);
        log.info("[routine speech] discarded stale or deleted : stepId={}", stepId);
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

  /// 한국어(또는 미지정) 일과이고 설명이 있는 단계만 (Supertonic F1 은 한국어 목소리)
  private static boolean isSpeakable(SpeechTextSource source) {
    boolean isKorean = source.getLanguage() == null || source.getLanguage() == AppLocale.KO;
    return isKorean && source.getDescription() != null && !source.getDescription().isBlank();
  }
}
