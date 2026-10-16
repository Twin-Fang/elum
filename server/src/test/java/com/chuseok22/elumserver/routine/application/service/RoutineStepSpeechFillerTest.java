package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.infrastructure.client.SupertonicTtsClient;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.core.RoutineStepSpeechText;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository.SpeechTextSource;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineStepSpeechStorage;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 단계 음성 1건 채우기 (#675). 실제 AI 서버를 부르지 않는다.
 */
@ExtendWith(MockitoExtension.class)
class RoutineStepSpeechFillerTest {

  private static final byte[] WAV = {82, 73, 70, 70};
  private static final String KEY = "step-1/hash.wav";

  @Mock private SupertonicTtsClient supertonicTtsClient;
  @Mock private RoutineStepSpeechStorage storage;
  @Mock private RoutineStepRepository repository;

  private RoutineStepSpeechFiller filler;

  @BeforeEach
  void setUp() {
    filler = new RoutineStepSpeechFiller(supertonicTtsClient, storage, repository);
    lenient().when(supertonicTtsClient.synthesize(anyString())).thenReturn(WAV);
    lenient().when(storage.save(anyString(), anyString(), any())).thenReturn(KEY);
  }

  @Test
  @DisplayName("문장으로 합성해 저장하고 열쇠를 채운다")
  void fill_savesAndUpdatesKey() {
    when(repository.findSpeechTextSource("step-1")).thenReturn(source("옷을 입어요", "학교 갈 옷을 입어요", AppLocale.KO));
    when(repository.updateSpeechPath("step-1", KEY)).thenReturn(1);

    assertThat(filler.fill("step-1")).isTrue();

    verify(supertonicTtsClient).synthesize("옷을 입어요. 학교 갈 옷을 입어요");
    verify(storage).save("step-1", RoutineStepSpeechText.hashOf("옷을 입어요. 학교 갈 옷을 입어요"), WAV);
  }

  @Test
  @DisplayName("AI 서버가 실패해도 던지지 않고 열쇠를 비워 둔다 — 일과 저장·화면이 깨지지 않게")
  void fill_ttsFails_swallowsAndKeepsNull() {
    when(repository.findSpeechTextSource("step-1")).thenReturn(source("손", "손을 씻어요", AppLocale.KO));
    when(supertonicTtsClient.synthesize(anyString())).thenThrow(new IllegalStateException("503"));

    assertThat(filler.fill("step-1")).isFalse();

    verify(repository, never()).updateSpeechPath(anyString(), anyString());
  }

  @Test
  @DisplayName("합성하는 사이 글이 바뀌면 만든 파일을 버린다 — 옛 문장이 새 카드에 붙지 않게")
  void fill_textChangedDuringSynthesis_discards() {
    when(repository.findSpeechTextSource("step-1"))
      .thenReturn(source("손", "손을 씻어요", AppLocale.KO))
      .thenReturn(source("손", "비누로 손을 씻어요", AppLocale.KO));

    filler.fill("step-1");

    verify(storage).delete(KEY);
    verify(repository, never()).updateSpeechPath(anyString(), anyString());
  }

  @Test
  @DisplayName("합성하는 사이 카드가 지워지면 파일을 지운다")
  void fill_stepDeletedDuringSynthesis_deletesFile() {
    when(repository.findSpeechTextSource("step-1")).thenReturn(source("손", "손을 씻어요", AppLocale.KO));
    when(repository.updateSpeechPath("step-1", KEY)).thenReturn(0);

    filler.fill("step-1");

    verify(storage).delete(KEY);
  }

  @Test
  @DisplayName("한국어가 아닌 일과는 합성하지 않는다 — 한국어 목소리로 다른 언어를 읽지 않게")
  void fill_nonKorean_skips() {
    when(repository.findSpeechTextSource("step-1")).thenReturn(source("Wash", "Wash your hands", AppLocale.EN));

    assertThat(filler.fill("step-1")).isTrue();

    verify(supertonicTtsClient, never()).synthesize(anyString());
  }

  @Test
  @DisplayName("지워진 카드는 합성하지 않는다")
  void fill_missingStep_skips() {
    when(repository.findSpeechTextSource("step-1")).thenReturn(Optional.empty());

    filler.fill("step-1");

    verify(supertonicTtsClient, never()).synthesize(anyString());
  }

  private static Optional<SpeechTextSource> source(String title, String description, AppLocale language) {
    return Optional.of(new SpeechTextSource() {
      @Override
      public String getTitle() {
        return title;
      }

      @Override
      public String getDescription() {
        return description;
      }

      @Override
      public AppLocale getLanguage() {
        return language;
      }
    });
  }
}
