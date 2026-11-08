package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.routine.application.service.RoutineQueryService.StepSpeech;
import com.chuseok22.elumserver.routine.application.service.RoutineStepSpeechDelivery.DeliveredSpeech;
import com.chuseok22.elumserver.routine.core.SpeechAudioFormat;
import com.chuseok22.elumserver.routine.infrastructure.audio.SpeechAudioCodec;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 단계 음성 응답 형식 (#1211). 옛 앱은 WAV 가 아니면 버리고 기기 음성으로 읽는다.
 */
@ExtendWith(MockitoExtension.class)
class RoutineStepSpeechDeliveryTest {

  private static final byte[] AAC = {0, 0, 0, 24, 102, 116, 121, 112};
  private static final byte[] WAV = {82, 73, 70, 70};

  @Mock private SpeechAudioCodec codec;

  private RoutineStepSpeechDelivery delivery;

  @BeforeEach
  void setUp() {
    delivery = new RoutineStepSpeechDelivery(codec);
  }

  @Test
  @DisplayName("m4a 를 받는 앱에는 저장본을 그대로 준다")
  void aacStored_newApp_returnsAsIs() {
    Optional<DeliveredSpeech> delivered = delivery.deliver(new StepSpeech("step-1/h.m4a", AAC), true);

    assertThat(delivered).hasValueSatisfying(speech -> {
      assertThat(speech.audio()).isEqualTo(AAC);
      assertThat(speech.format()).isEqualTo(SpeechAudioFormat.AAC);
    });
    verify(codec, never()).toWav(any());
  }

  @Test
  @DisplayName("옛 앱에는 m4a 를 WAV 로 되돌려 준다 — 운영 옛 앱 목소리가 그대로 나오게")
  void aacStored_oldApp_returnsWav() {
    when(codec.toWav(AAC)).thenReturn(Optional.of(WAV));

    Optional<DeliveredSpeech> delivered = delivery.deliver(new StepSpeech("step-1/h.m4a", AAC), false);

    assertThat(delivered).hasValueSatisfying(speech -> {
      assertThat(speech.audio()).isEqualTo(WAV);
      assertThat(speech.format()).isEqualTo(SpeechAudioFormat.WAV);
    });
  }

  @Test
  @DisplayName("되돌리기에 실패하면 빈 값 — m4a 를 wav 라고 속여 보내지 않게 (앱은 기기 음성)")
  void aacStored_oldApp_decodeFails_isEmpty() {
    when(codec.toWav(AAC)).thenReturn(Optional.empty());

    assertThat(delivery.deliver(new StepSpeech("step-1/h.m4a", AAC), false)).isEmpty();
  }

  @Test
  @DisplayName("아직 WAV 인 저장본은 어느 앱이든 그대로 준다 (새 앱도 wav 를 재생)")
  void wavStored_returnsAsIs() {
    assertThat(delivery.deliver(new StepSpeech("step-1/h.wav", WAV), true))
      .hasValueSatisfying(speech -> assertThat(speech.format()).isEqualTo(SpeechAudioFormat.WAV));
    assertThat(delivery.deliver(new StepSpeech("step-1/h.wav", WAV), false))
      .hasValueSatisfying(speech -> assertThat(speech.audio()).isEqualTo(WAV));
    verify(codec, never()).toWav(any());
  }
}
