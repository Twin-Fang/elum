package com.chuseok22.elumserver.routine.core;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 보호자 녹음 검사 (#787): 깨지면 이룸이 기기가 재생 못 하는 파일·긴 파일이 저장된다
 */
class GuardianVoiceAudioTest {

  @Test
  @DisplayName("m4a 15초 이하면 길이를 돌려준다 (moov 가 뒤에 있어도)")
  void inspect_acceptsShortM4a() {
    assertThat(GuardianVoiceAudio.inspect(GuardianVoiceAudioFixture.m4aOfMillis(3_500))).isEqualTo(3_500);
    assertThat(GuardianVoiceAudio.inspect(GuardianVoiceAudioFixture.m4a(44_100, 44_100L * 15))).isEqualTo(15_000);
  }

  @Test
  @DisplayName("16초를 넘으면 TOO_LONG")
  void inspect_rejectsTooLong() {
    assertRejected(GuardianVoiceAudioFixture.m4aOfMillis(16_001), ErrorCode.GUARDIAN_VOICE_TOO_LONG);
  }

  @Test
  @DisplayName("1MB 를 넘으면 형식을 보기 전에 TOO_LARGE")
  void inspect_rejectsTooLarge() {
    assertRejected(new byte[(int) GuardianVoiceAudio.MAX_BYTES + 1], ErrorCode.GUARDIAN_VOICE_TOO_LARGE);
  }

  @Test
  @DisplayName("WAV·빈 파일·HTML·moov 없는 m4a·잘린 파일은 INVALID_TYPE (선언한 형식은 믿지 않음)")
  void inspect_rejectsNotM4a() {
    byte[] wav = "RIFF\0\0\0\0WAVEfmt ".getBytes(StandardCharsets.ISO_8859_1);
    byte[] html = "<html>error</html>".getBytes(StandardCharsets.ISO_8859_1);
    byte[] full = GuardianVoiceAudioFixture.m4aOfMillis(2_000);
    byte[] withoutMoov = Arrays.copyOf(full, 16 + 40);
    byte[] truncated = Arrays.copyOf(full, full.length - 6);
    for (byte[] audio : new byte[][] {wav, html, new byte[0], withoutMoov, truncated,
      GuardianVoiceAudioFixture.m4aOfMillis(0)}) {
      assertRejected(audio, ErrorCode.GUARDIAN_VOICE_INVALID_TYPE);
    }
  }

  private static void assertRejected(byte[] audio, ErrorCode expected) {
    assertThatThrownBy(() -> GuardianVoiceAudio.inspect(audio))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(expected));
  }
}
