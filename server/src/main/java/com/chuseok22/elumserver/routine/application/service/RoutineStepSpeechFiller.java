package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.infrastructure.client.SupertonicTtsClient;
import com.chuseok22.elumserver.common.infrastructure.logging.LogTextLength;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.core.RoutineStepSpeechText;
import com.chuseok22.elumserver.routine.core.SpeechAudioFormat;
import com.chuseok22.elumserver.routine.infrastructure.audio.SpeechAudioCodec;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository.SpeechTextSource;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineStepSpeechStorage;
import java.util.Optional;
import java.util.function.Function;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 단계 음성 1건 채우기: 단계 확인 > 문장 > 합성 > AAC 압축 > 저장 > 문장 재확인 > 열쇠 갱신 (#675, #1211)
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
  private final SpeechAudioCodec speechAudioCodec;

  public boolean fill(String stepId) {
    try {
      fillWith(stepId, supertonicTtsClient::synthesize);
      return true;
    } catch (Exception e) {
      logFailure(stepId, e);
      return false;
    }
  }

  /**
   * 요청 중 즉석 채우기 (#765): 같은 규칙에 합성 읽기 제한만 6초
   * 반환: 저장된 음성, 건너뜀·폐기·실패면 빈 값 (던지지 않음)
   */
  public Optional<FilledSpeech> fillOnDemand(String stepId) {
    try {
      return fillWith(stepId, supertonicTtsClient::synthesizeWithinOnDemandLimit);
    } catch (Exception e) {
      logFailure(stepId, e);
      return Optional.empty();
    }
  }

  /// 단계 확인 > 합성 > 압축 > 저장 > 문장 재확인 > 열쇠 갱신. 건너뜀·폐기는 빈 값, 합성·저장 실패는 예외
  private Optional<FilledSpeech> fillWith(String stepId, Function<String, byte[]> synthesizer) {
    // 단계 확인 (지워졌거나 한국어 아닌 일과, 빈 설명이면 건너뜀)
    Optional<SpeechTextSource> source = routineStepRepository.findSpeechTextSource(stepId)
      .filter(RoutineStepSpeechFiller::isSpeakable);
    if (source.isEmpty()) {
      return Optional.empty();
    }
    String title = source.get().getTitle();
    String description = source.get().getDescription();
    String text = RoutineStepSpeechText.of(title, description);

    // 합성 > 압축 > 저장
    long startedAt = System.currentTimeMillis();
    byte[] wav = synthesizer.apply(text);
    StoredAudio stored = compress(wav);
    String speechKey = routineStepSpeechStorage.save(stepId, RoutineStepSpeechText.hashOf(text), stored.bytes(), stored.format());

    // 열쇠 갱신: 합성에 쓴 글이 지금도 같을 때만 (0 = 그새 글 수정 또는 삭제 > 파일 버림, 새 글은 다시 예약됨)
    if (routineStepRepository.updateSpeechPathIfTextUnchanged(
      stepId, speechKey, title == null ? "" : title, description) == 0) {
      routineStepSpeechStorage.delete(speechKey);
      log.info("[routine speech] discarded stale or deleted : stepId={}", stepId);
      return Optional.empty();
    }
    log.info("[routine speech] saved : stepId={}, textLength={}, format={}, bytes={} -> {}, elapsedMs={}",
      stepId, LogTextLength.of(text), stored.format(), wav.length, stored.bytes().length,
      System.currentTimeMillis() - startedAt);
    return Optional.of(new FilledSpeech(speechKey, stored.bytes()));
  }

  /// WAV > AAC. 변환 실패면 WAV 그대로 (음성이 빠지지 않게)
  private StoredAudio compress(byte[] wav) {
    return speechAudioCodec.toAac(wav)
      .map(aac -> new StoredAudio(aac, SpeechAudioFormat.AAC))
      .orElseGet(() -> new StoredAudio(wav, SpeechAudioFormat.WAV));
  }

  /// 저장할 바이트와 형식
  private record StoredAudio(byte[] bytes, SpeechAudioFormat format) {

  }

  private static void logFailure(String stepId, Exception e) {
    log.warn("[routine speech] failed : stepId={}, cause={}: {}",
      stepId, e.getClass().getSimpleName(), e.getMessage());
  }

  /// 방금 저장한 음성: 열쇠(앱 캐시 이름·ETag, 확장자 = 형식), 저장한 바이트
  public record FilledSpeech(String speechKey, byte[] audio) {

  }

  /// 한국어(또는 미지정) 일과이고 설명이 있는 단계만 (Supertonic F1 은 한국어 목소리)
  private static boolean isSpeakable(SpeechTextSource source) {
    boolean isKorean = source.getLanguage() == null || source.getLanguage() == AppLocale.KO;
    return isKorean && source.getDescription() != null && !source.getDescription().isBlank();
  }
}
