package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.infrastructure.client.SupertonicTtsClient;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.TtsProperties;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.service.RoutineQueryService.StepSpeech;
import com.chuseok22.elumserver.routine.application.service.RoutineStepSpeechFiller.FilledSpeech;
import java.time.Duration;
import java.util.Optional;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.TestingAuthenticationToken;

/**
 * 단계 음성 제공 (#765): 저장본 우선, 없으면 한 번만 즉석 합성, 상한·실패·시간 초과는 빈 값(404). 실제 AI 서버를 부르지 않는다.
 */
class RoutineStepSpeechProviderTest {

  private static final byte[] WAV = {82, 73, 70, 70};
  private static final String KEY = "step-1/hash.wav";

  private final RoutineQueryService queryService = mock(RoutineQueryService.class);
  private final RoutineStepSpeechFiller filler = mock(RoutineStepSpeechFiller.class);
  private final SupertonicTtsClient ttsClient = mock(SupertonicTtsClient.class);
  private final Caller caller = Caller.from(new TestingAuthenticationToken("member-1", null));

  private ExecutorService executor;
  private ExecutorService requestThreads;

  @BeforeEach
  void setUp() {
    executor = Executors.newFixedThreadPool(4);
    requestThreads = Executors.newFixedThreadPool(4);
    when(ttsClient.isAvailable()).thenReturn(true);
    when(queryService.getStepSpeech(any(), anyString(), anyString())).thenReturn(Optional.empty());
  }

  @AfterEach
  void tearDown() {
    executor.shutdownNow();
    requestThreads.shutdownNow();
  }

  private RoutineStepSpeechProvider provider(int maxConcurrent, Duration maxWait) {
    return new RoutineStepSpeechProvider(queryService, filler, new TtsProperties(true, null), ttsClient,
      executor, maxConcurrent, maxWait);
  }

  @Test
  @DisplayName("저장 음성이 있으면 합성을 부르지 않는다")
  void storedSpeech_skipsSynthesis() {
    when(queryService.getStepSpeech(any(), anyString(), anyString())).thenReturn(Optional.of(new StepSpeech(KEY, WAV)));

    Optional<StepSpeech> speech = provider(2, Duration.ofSeconds(2)).getStepSpeech(caller, "r1", "step-1");

    assertThat(speech).contains(new StepSpeech(KEY, WAV));
    verify(filler, never()).fillOnDemand(anyString());
  }

  @Test
  @DisplayName("저장 음성이 없으면 한 번 합성해 저장한 열쇠와 WAV 를 돌려준다")
  void missingSpeech_synthesizesOnce() {
    when(filler.fillOnDemand("step-1")).thenReturn(Optional.of(new FilledSpeech(KEY, WAV)));

    Optional<StepSpeech> speech = provider(2, Duration.ofSeconds(2)).getStepSpeech(caller, "r1", "step-1");

    assertThat(speech.orElseThrow().speechKey()).isEqualTo(KEY);
    assertThat(speech.get().wav()).isEqualTo(WAV);
    verify(filler, times(1)).fillOnDemand("step-1");
  }

  @Test
  @DisplayName("같은 단계에 동시 요청 둘이 와도 합성은 한 번이고 둘 다 같은 음성을 받는다")
  void concurrentRequests_synthesizeOnce() throws Exception {
    CountDownLatch synthesisStarted = new CountDownLatch(1);
    CountDownLatch releaseSynthesis = new CountDownLatch(1);
    when(filler.fillOnDemand("step-1")).thenAnswer(invocation -> {
      synthesisStarted.countDown();
      releaseSynthesis.await(5, TimeUnit.SECONDS);
      return Optional.of(new FilledSpeech(KEY, WAV));
    });
    RoutineStepSpeechProvider provider = provider(2, Duration.ofSeconds(5));

    Future<Optional<StepSpeech>> first = requestThreads.submit(() -> provider.getStepSpeech(caller, "r1", "step-1"));
    assertThat(synthesisStarted.await(5, TimeUnit.SECONDS)).isTrue();
    Future<Optional<StepSpeech>> second = requestThreads.submit(() -> provider.getStepSpeech(caller, "r1", "step-1"));
    Thread.sleep(200);
    releaseSynthesis.countDown();

    assertThat(first.get(5, TimeUnit.SECONDS)).isPresent();
    assertThat(second.get(5, TimeUnit.SECONDS)).isPresent();
    verify(filler, times(1)).fillOnDemand("step-1");
  }

  @Test
  @DisplayName("동시 합성 상한을 넘은 다른 단계 요청은 합성하지 않고 빈 값(404)을 돌려준다")
  void overLimit_returnsEmpty() throws Exception {
    CountDownLatch synthesisStarted = new CountDownLatch(1);
    CountDownLatch releaseSynthesis = new CountDownLatch(1);
    when(filler.fillOnDemand("step-1")).thenAnswer(invocation -> {
      synthesisStarted.countDown();
      releaseSynthesis.await(5, TimeUnit.SECONDS);
      return Optional.of(new FilledSpeech(KEY, WAV));
    });
    RoutineStepSpeechProvider provider = provider(1, Duration.ofSeconds(5));

    Future<Optional<StepSpeech>> running = requestThreads.submit(() -> provider.getStepSpeech(caller, "r1", "step-1"));
    assertThat(synthesisStarted.await(5, TimeUnit.SECONDS)).isTrue();

    assertThat(provider.getStepSpeech(caller, "r1", "step-2")).isEmpty();
    verify(filler, never()).fillOnDemand("step-2");

    releaseSynthesis.countDown();
    assertThat(running.get(5, TimeUnit.SECONDS)).isPresent();
  }

  @Test
  @DisplayName("합성이 비어 돌아오거나(실패·비한국어·글 변경) 시간을 넘기면 빈 값(404)을 돌려준다")
  void failureOrTimeout_returnsEmpty() throws Exception {
    when(filler.fillOnDemand("step-1")).thenReturn(Optional.empty());
    assertThat(provider(2, Duration.ofSeconds(2)).getStepSpeech(caller, "r1", "step-1")).isEmpty();

    CountDownLatch neverReleased = new CountDownLatch(1);
    when(filler.fillOnDemand("step-2")).thenAnswer(invocation -> {
      neverReleased.await(3, TimeUnit.SECONDS);
      return Optional.of(new FilledSpeech(KEY, WAV));
    });
    assertThat(provider(2, Duration.ofMillis(100)).getStepSpeech(caller, "r1", "step-2")).isEmpty();
    neverReleased.countDown();
  }

  @Test
  @DisplayName("AI 서버 키가 없거나 설정이 꺼져 있으면 합성하지 않는다")
  void disabled_skipsSynthesis() {
    when(ttsClient.isAvailable()).thenReturn(false);

    assertThat(provider(2, Duration.ofSeconds(2)).getStepSpeech(caller, "r1", "step-1")).isEmpty();

    verify(filler, never()).fillOnDemand(anyString());
  }

  @Test
  @DisplayName("권한이 없는 요청은 기존 예외 그대로 거부되고 합성하지 않는다")
  void forbidden_rejectedWithoutSynthesis() {
    when(queryService.getStepSpeech(any(), anyString(), anyString()))
      .thenThrow(new CustomException(ErrorCode.ROUTINE_ACCESS_DENIED));

    assertThatThrownBy(() -> provider(2, Duration.ofSeconds(2)).getStepSpeech(caller, "r1", "step-1"))
      .isInstanceOf(CustomException.class);

    verify(filler, never()).fillOnDemand(anyString());
  }
}
