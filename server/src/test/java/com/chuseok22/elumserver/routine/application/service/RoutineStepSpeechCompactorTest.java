package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.routine.application.service.RoutineStepSpeechCompactor.CompactResult;
import com.chuseok22.elumserver.routine.core.SpeechAudioFormat;
import com.chuseok22.elumserver.routine.infrastructure.audio.SpeechAudioCodec;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository.StoredSpeechPath;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineStepSpeechStorage;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 저장된 WAV > AAC 전환 (#1211). 열쇠와 파일이 어긋나면 카드 음성이 사라진다.
 */
@ExtendWith(MockitoExtension.class)
class RoutineStepSpeechCompactorTest {

  private static final String WAV_KEY = "step-1/hash.wav";
  private static final String AAC_KEY = "step-1/hash.m4a";
  private static final byte[] WAV = {82, 73, 70, 70};
  private static final byte[] AAC = {0, 0, 0, 24, 102, 116, 121, 112};

  @Mock private RoutineStepRepository repository;
  @Mock private RoutineStepSpeechStorage storage;
  @Mock private SpeechAudioCodec codec;
  @Mock private MigrationLock migrationLock;

  private RoutineStepSpeechCompactor compactor;

  @BeforeEach
  void setUp() {
    compactor = new RoutineStepSpeechCompactor(repository, storage, codec, migrationLock);
  }

  @Test
  @DisplayName("같은 해시의 .m4a 로 저장하고 열쇠를 바꾼 뒤 옛 wav 를 지운다")
  void compactOne_replacesKeyThenDeletesWav() {
    when(storage.read(WAV_KEY)).thenReturn(Optional.of(WAV));
    when(codec.toAac(WAV)).thenReturn(Optional.of(AAC));
    when(storage.save("step-1", "hash", AAC, SpeechAudioFormat.AAC)).thenReturn(AAC_KEY);
    when(repository.replaceSpeechPath("step-1", WAV_KEY, AAC_KEY)).thenReturn(1);

    assertThat(compactor.compactOne("step-1", WAV_KEY)).isEqualTo(CompactResult.COMPACTED);

    verify(storage).delete(WAV_KEY);
    verify(storage, never()).delete(AAC_KEY);
  }

  @Test
  @DisplayName("그새 글이 바뀌어 열쇠 교체가 0건이면 새 파일만 지운다 — 새 음성의 열쇠를 옛 음성으로 덮지 않게")
  void compactOne_keyChanged_deletesNewFileOnly() {
    when(storage.read(WAV_KEY)).thenReturn(Optional.of(WAV));
    when(codec.toAac(WAV)).thenReturn(Optional.of(AAC));
    when(storage.save("step-1", "hash", AAC, SpeechAudioFormat.AAC)).thenReturn(AAC_KEY);
    when(repository.replaceSpeechPath("step-1", WAV_KEY, AAC_KEY)).thenReturn(0);

    assertThat(compactor.compactOne("step-1", WAV_KEY)).isEqualTo(CompactResult.SKIPPED);

    verify(storage).delete(AAC_KEY);
    verify(storage, never()).delete(WAV_KEY);
  }

  @Test
  @DisplayName("변환에 실패하면 wav 와 열쇠를 그대로 두고 이번 주기를 멈춘다")
  void compact_codecFails_keepsWavAndStops() {
    when(repository.findWavSpeechPaths(any())).thenReturn(List.of(row("step-1", WAV_KEY), row("step-2", "step-2/h.wav")));
    when(storage.read(WAV_KEY)).thenReturn(Optional.of(WAV));
    when(codec.toAac(WAV)).thenReturn(Optional.empty());

    compactor.compact();

    verify(storage, never()).save(anyString(), anyString(), any(), any());
    verify(repository, never()).replaceSpeechPath(anyString(), anyString(), anyString());
    verify(storage, times(1)).read(anyString());
  }

  @Test
  @DisplayName("서버 이전 잠금 중이면 아무것도 바꾸지 않는다")
  void compact_skipsWhileMigrationLocked() {
    when(migrationLock.isBlockingScheduledJob("RoutineStepSpeechCompactor")).thenReturn(true);

    compactor.compact();

    verify(repository, never()).findWavSpeechPaths(any());
  }

  private static StoredSpeechPath row(String stepId, String speechPath) {
    return new StoredSpeechPath() {
      @Override
      public String getStepId() {
        return stepId;
      }

      @Override
      public String getSpeechPath() {
        return speechPath;
      }
    };
  }
}
