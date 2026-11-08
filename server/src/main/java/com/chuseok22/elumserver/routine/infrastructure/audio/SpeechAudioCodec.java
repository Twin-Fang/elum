package com.chuseok22.elumserver.routine.infrastructure.audio;

import java.util.Optional;

/**
 * 단계 음성 형식 변환: WAV > AAC(m4a) 저장용, AAC > WAV 옛 앱 응답용 (#1211)
 * 어떤 실패도 던지지 않음 (빈 값 > 호출부가 원래 바이트로 진행)
 */
public interface SpeechAudioCodec {

  /**
   * WAV > AAC(m4a). 실패·시간 초과면 빈 값
   */
  Optional<byte[]> toAac(byte[] wav);

  /**
   * AAC(m4a) > WAV. 실패·시간 초과면 빈 값
   */
  Optional<byte[]> toWav(byte[] aac);
}
