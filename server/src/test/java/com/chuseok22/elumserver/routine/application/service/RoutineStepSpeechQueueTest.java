package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.infrastructure.client.SupertonicTtsClient;
import com.chuseok22.elumserver.common.infrastructure.properties.TtsProperties;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineStepSpeechStorage;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.AbstractExecutorService;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 단계 음성 대기열 (#675). AI 서버는 하나씩 처리하므로 같은 단계를 두 번 보내면 대기만 늘어난다.
 */
@ExtendWith(MockitoExtension.class)
class RoutineStepSpeechQueueTest {

  @Mock private RoutineStepSpeechFiller filler;
  @Mock private RoutineStepSpeechStorage storage;
  @Mock private SupertonicTtsClient supertonicTtsClient;

  /// 넣은 작업을 모아 두었다가 runAll 때 실행 (단일 스레드 대신)
  private final ManualExecutor executor = new ManualExecutor();
  private final Instant now = Instant.parse("2026-10-16T00:00:00Z");

  private RoutineStepSpeechQueue queue;

  @BeforeEach
  void setUp() {
    lenient().when(supertonicTtsClient.isAvailable()).thenReturn(true);
    queue = new RoutineStepSpeechQueue(filler, storage, new TtsProperties(true, "x"), supertonicTtsClient,
      executor, Clock.fixed(now, ZoneOffset.UTC));
  }

  @Test
  @DisplayName("대기 중인 단계를 또 넣으면 한 번만 처리한다")
  void enqueue_duplicate_runsOnce() {
    queue.enqueue("step-1");
    queue.enqueue("step-1");
    executor.runAll();

    verify(filler, times(1)).fill("step-1");
    assertThat(queue.pendingCount()).isZero();
  }

  @Test
  @DisplayName("처리가 끝난 단계는 다시 넣을 수 있다 — 글을 또 고치면 다시 만든다")
  void enqueue_afterDone_runsAgain() {
    queue.enqueue("step-1");
    executor.runAll();
    queue.enqueue("step-1");
    executor.runAll();

    verify(filler, times(2)).fill("step-1");
  }

  @Test
  @DisplayName("합성에 실패한 단계는 잠시 쉰다 — 주기 작업이 같은 실패 단계로 자리를 채우지 않게")
  void failedStep_coolsDown() {
    when(filler.fill("step-1")).thenReturn(false);
    queue.enqueue("step-1");
    executor.runAll();

    assertThat(queue.isCoolingDown("step-1")).isTrue();
    assertThat(queue.isCoolingDown("step-2")).isFalse();
  }

  @Test
  @DisplayName("AI 서버 키가 없으면 아무것도 넣지 않는다")
  void disabled_withoutApiKey() {
    when(supertonicTtsClient.isAvailable()).thenReturn(false);

    queue.enqueue("step-1");
    queue.enqueueAfterCommit(List.of("step-2"));
    executor.runAll();

    verify(filler, never()).fill(anyString());
  }

  /// 실패 쉬는 시간 확인용 (30분)
  @Test
  @DisplayName("쉬는 시간이 지나면 다시 시도할 수 있다")
  void coolDown_expires() {
    when(filler.fill("step-1")).thenReturn(false);
    queue.enqueue("step-1");
    executor.runAll();

    RoutineStepSpeechQueue later = new RoutineStepSpeechQueue(filler, storage, new TtsProperties(true, "x"),
      supertonicTtsClient, executor, Clock.fixed(now.plus(Duration.ofMinutes(31)), ZoneOffset.UTC));

    assertThat(later.isCoolingDown("step-1")).isFalse();
  }

  private static final class ManualExecutor extends AbstractExecutorService {

    private final List<Runnable> tasks = new ArrayList<>();

    void runAll() {
      List<Runnable> current = new ArrayList<>(tasks);
      tasks.clear();
      current.forEach(Runnable::run);
    }

    @Override
    public void execute(Runnable command) {
      tasks.add(command);
    }

    @Override
    public void shutdown() {
    }

    @Override
    public List<Runnable> shutdownNow() {
      return List.of();
    }

    @Override
    public boolean isShutdown() {
      return false;
    }

    @Override
    public boolean isTerminated() {
      return false;
    }

    @Override
    public boolean awaitTermination(long timeout, TimeUnit unit) {
      return true;
    }
  }
}
