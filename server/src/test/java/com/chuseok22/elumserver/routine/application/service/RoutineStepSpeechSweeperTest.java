package com.chuseok22.elumserver.routine.application.service;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import java.util.List;
import java.util.stream.IntStream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 빠진 단계 음성 메우기 (#675). AI 서버가 꺼졌던 동안 만든 일과도 결국 음성을 받아야 한다.
 */
@ExtendWith(MockitoExtension.class)
class RoutineStepSpeechSweeperTest {

  @Mock private RoutineStepRepository repository;
  @Mock private RoutineStepSpeechQueue queue;
  @InjectMocks private RoutineStepSpeechSweeper sweeper;

  @Test
  @DisplayName("한국어 단계만 고르고 한 번에 20건까지 넣는다 — AI 서버가 한꺼번에 몰리지 않게")
  void sweep_enqueuesUpToBatch() {
    when(queue.isEnabled()).thenReturn(true);
    List<String> ids = IntStream.rangeClosed(1, 30).mapToObj(i -> "step-" + i).toList();
    when(repository.findIdsMissingSpeech(eq(AppLocale.KO), any())).thenReturn(ids);

    sweeper.sweep();

    verify(queue, times(RoutineStepSpeechSweeper.SWEEP_BATCH_SIZE)).enqueue(anyString());
  }

  @Test
  @DisplayName("쉬는 중인 실패 단계는 건너뛴다")
  void sweep_skipsCoolingDown() {
    when(queue.isEnabled()).thenReturn(true);
    when(repository.findIdsMissingSpeech(eq(AppLocale.KO), any())).thenReturn(List.of("step-1", "step-2"));
    when(queue.isCoolingDown("step-1")).thenReturn(true);

    sweeper.sweep();

    verify(queue, never()).enqueue("step-1");
    verify(queue).enqueue("step-2");
  }

  @Test
  @DisplayName("이전 분량을 처리 중이면 건너뛴다")
  void sweep_skipsWhileBusy() {
    when(queue.isEnabled()).thenReturn(true);
    when(queue.pendingCount()).thenReturn(3);

    sweeper.sweep();

    verify(repository, never()).findIdsMissingSpeech(any(), any());
  }
}
