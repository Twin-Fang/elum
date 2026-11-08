package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.routine.core.SpeechAudioFormat;
import com.chuseok22.elumserver.routine.infrastructure.audio.SpeechAudioCodec;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository.StoredSpeechPath;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineStepSpeechStorage;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 저장된 WAV 음성 > AAC 전환 (#1211): 읽기 > 변환 > 새 열쇠로 저장 > 열쇠 교체 > 옛 파일 삭제
 * 2분마다 최대 30건. 변환이 안 되면(ffmpeg 없음 등) 이번 주기는 멈추고 WAV 그대로 둠
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineStepSpeechCompactor {

  // 한 주기 최대 건수 (실측 변환 1건 약 0.17초 > 30건 약 5초)
  static final int COMPACT_BATCH_SIZE = 30;

  private final RoutineStepRepository routineStepRepository;
  private final RoutineStepSpeechStorage routineStepSpeechStorage;
  private final SpeechAudioCodec speechAudioCodec;
  private final MigrationLock migrationLock;

  @Scheduled(fixedDelayString = "PT2M", initialDelayString = "PT3M")
  public void compact() {
    if (migrationLock.isBlockingScheduledJob("RoutineStepSpeechCompactor")) {
      return;
    }
    try {
      List<StoredSpeechPath> wavSpeeches = routineStepRepository.findWavSpeechPaths(PageRequest.of(0, COMPACT_BATCH_SIZE));
      int compactedCount = 0;
      for (StoredSpeechPath wavSpeech : wavSpeeches) {
        CompactResult compactResult = compactOne(wavSpeech.getStepId(), wavSpeech.getSpeechPath());
        if (compactResult == CompactResult.CODEC_FAILED) {
          break;
        }
        if (compactResult == CompactResult.COMPACTED) {
          compactedCount++;
        }
      }
      if (!wavSpeeches.isEmpty()) {
        log.info("[routine speech] compacted : count={}, scanned={}", compactedCount, wavSpeeches.size());
      }
    } catch (Exception e) {
      // 조회 실패해도 다음 주기에 다시 (스케줄러 스레드 보호)
      log.warn("[routine speech] compact failed : cause={}", e.getClass().getSimpleName(), e);
    }
  }

  /// 1건 전환. 열쇠 교체가 안 되면(그새 글 수정·삭제) 새 파일을 버림
  CompactResult compactOne(String stepId, String wavSpeechKey) {
    Optional<byte[]> wav = routineStepSpeechStorage.read(wavSpeechKey);
    if (wav.isEmpty()) {
      return CompactResult.SKIPPED;
    }
    Optional<byte[]> aac = speechAudioCodec.toAac(wav.get());
    if (aac.isEmpty()) {
      log.warn("[routine speech] compact stopped : stepId={}, reason=codec failed", stepId);
      return CompactResult.CODEC_FAILED;
    }
    String aacSpeechKey = routineStepSpeechStorage.save(
      stepId, SpeechAudioFormat.textHashOf(wavSpeechKey), aac.get(), SpeechAudioFormat.AAC);
    if (routineStepRepository.replaceSpeechPath(stepId, wavSpeechKey, aacSpeechKey) == 0) {
      routineStepSpeechStorage.delete(aacSpeechKey);
      return CompactResult.SKIPPED;
    }
    routineStepSpeechStorage.delete(wavSpeechKey);
    return CompactResult.COMPACTED;
  }

  /// 1건 결과 3가지: 전환함, 건너뜀(파일 없음·열쇠 바뀜), 변환 실패(이번 주기 멈춤)
  enum CompactResult {
    COMPACTED, SKIPPED, CODEC_FAILED
  }
}
