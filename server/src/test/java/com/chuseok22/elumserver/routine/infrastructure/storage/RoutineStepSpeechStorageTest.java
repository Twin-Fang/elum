package com.chuseok22.elumserver.routine.infrastructure.storage;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.infrastructure.properties.TtsProperties;
import com.chuseok22.elumserver.routine.core.SpeechAudioFormat;
import java.nio.file.Files;
import java.nio.file.Path;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/**
 * 단계 음성 저장소 (#675). 열쇠가 폴더 밖을 가리키면 남의 파일을 읽고 지울 수 있다.
 */
class RoutineStepSpeechStorageTest {

  @TempDir
  Path tempDir;

  private RoutineStepSpeechStorage storage;

  @BeforeEach
  void setUp() {
    storage = new LocalFileRoutineStepSpeechStorage(new TtsProperties(true, tempDir.toString()));
  }

  @Test
  @DisplayName("저장한 음성을 열쇠로 다시 읽는다")
  void saveThenRead() {
    String key = storage.save("step-1", "abcd", new byte[]{1, 2, 3}, SpeechAudioFormat.WAV);

    assertThat(key).isEqualTo("step-1/abcd.wav");
    assertThat(storage.read(key)).hasValueSatisfying(wav -> assertThat(wav).containsExactly(1, 2, 3));
  }

  @Test
  @DisplayName("AAC 는 .m4a 열쇠로 저장한다 — 확장자로 형식을 판정하므로 틀리면 옛 앱에 m4a 가 그대로 나감")
  void save_aac_usesM4aKey() {
    String key = storage.save("step-1", "abcd", new byte[]{1}, SpeechAudioFormat.AAC);

    assertThat(key).isEqualTo("step-1/abcd.m4a");
    assertThat(SpeechAudioFormat.ofKey(key)).isEqualTo(SpeechAudioFormat.AAC);
    assertThat(SpeechAudioFormat.textHashOf(key)).isEqualTo("abcd");
  }

  @Test
  @DisplayName("폴더 밖을 가리키는 열쇠는 읽지 않는다")
  void read_outsideBase_isEmpty() throws Exception {
    Files.writeString(tempDir.getParent().resolve("secret.txt"), "x");

    assertThat(storage.read("../secret.txt")).isEmpty();
  }

  @Test
  @DisplayName("단계 폴더만 지우고 다른 단계는 남긴다")
  void deleteStep_onlyThatStep() {
    String deleted = storage.save("step-1", "a", new byte[]{1}, SpeechAudioFormat.WAV);
    String kept = storage.save("step-2", "b", new byte[]{2}, SpeechAudioFormat.WAV);

    storage.deleteStep("step-1");

    assertThat(storage.read(deleted)).isEmpty();
    assertThat(storage.read(kept)).isPresent();
  }

  @Test
  @DisplayName("저장 폴더 자체나 폴더 밖은 지우지 않는다")
  void deleteStep_rejectsBaseAndOutside() {
    String kept = storage.save("step-1", "a", new byte[]{1}, SpeechAudioFormat.WAV);

    storage.deleteStep("..");
    storage.deleteStep(".");

    assertThat(storage.read(kept)).isPresent();
  }
}
