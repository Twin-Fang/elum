package com.chuseok22.elumserver.routine.infrastructure.storage;

import com.chuseok22.elumserver.routine.core.SpeechAudioFormat;
import java.util.Optional;

/**
 * 단계 음성 저장소: 저장, 조회, 삭제 (#675)
 * 열쇠 {stepId}/{문장 해시}.m4a(또는 .wav) > DB routine_step.speech_path. 그림 저장소와 같은 열쇠 방식
 */
public interface RoutineStepSpeechStorage {

  /**
   * 음성 저장 > 열쇠 (확장자 = 형식)
   */
  String save(String stepId, String textHash, byte[] audio, SpeechAudioFormat format);

  /**
   * 열쇠 > 음성 바이트. 없거나 폴더 밖 열쇠면 빈 값
   */
  Optional<byte[]> read(String key);

  /**
   * 파일 1개 삭제 (실패는 기록만)
   */
  void delete(String key);

  /**
   * 단계 폴더째 삭제 (단계·일과 삭제 시)
   */
  void deleteStep(String stepId);
}
