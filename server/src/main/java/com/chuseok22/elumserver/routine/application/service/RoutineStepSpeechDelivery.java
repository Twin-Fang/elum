package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.routine.application.service.RoutineQueryService.StepSpeech;
import com.chuseok22.elumserver.routine.core.SpeechAudioFormat;
import com.chuseok22.elumserver.routine.infrastructure.audio.SpeechAudioCodec;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 단계 음성 응답 형식 맞추기 (#1211): m4a 를 받는 앱은 저장본 그대로, 그 외(옛 앱)는 WAV 로 되돌려 응답
 * 옛 앱은 WAV 머리가 아니면 버리고 기기 음성으로 읽음 > 저장 형식이 바뀌어도 옛 앱 목소리는 그대로
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineStepSpeechDelivery {

  private final SpeechAudioCodec speechAudioCodec;

  /**
   * 저장된 음성 > 앱이 받을 형식의 음성. 되돌리기 실패면 빈 값 (앱은 기기 음성)
   */
  public Optional<DeliveredSpeech> deliver(StepSpeech speech, boolean canPlayAac) {
    SpeechAudioFormat storedFormat = SpeechAudioFormat.ofKey(speech.speechKey());
    if (storedFormat == SpeechAudioFormat.WAV || canPlayAac) {
      return Optional.of(new DeliveredSpeech(speech.audio(), storedFormat));
    }
    Optional<byte[]> wav = speechAudioCodec.toWav(speech.audio());
    if (wav.isEmpty()) {
      log.warn("[routine speech] wav fallback failed : speechKey={}", speech.speechKey());
    }
    return wav.map(bytes -> new DeliveredSpeech(bytes, SpeechAudioFormat.WAV));
  }

  /// 응답할 음성: 바이트, 형식(Content-Type)
  public record DeliveredSpeech(byte[] audio, SpeechAudioFormat format) {

  }
}
