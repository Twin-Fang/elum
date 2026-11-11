package com.chuseok22.elumserver.routine.infrastructure.audio;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import com.chuseok22.elumserver.routine.core.GuardianVoiceAudio;
import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 실제 ffmpeg 로 음성 변환 (#1211). ffmpeg 가 없는 곳에서는 변환 시험을 건너뛴다.
 */
class FfmpegSpeechAudioCodecTest {

  private final FfmpegSpeechAudioCodec codec = new FfmpegSpeechAudioCodec();

  @Test
  @DisplayName("WAV 를 더 작은 m4a 로 바꾸고, 되돌리면 WAV 머리가 나온다 — 옛 앱 머리 검사 통과")
  void wavToAacAndBack() {
    assumeTrue(isFfmpegInstalled(), "ffmpeg 없음");
    byte[] wav = sineWav(2);

    byte[] aac = codec.toAac(wav).orElseThrow();
    byte[] restored = codec.toWav(aac).orElseThrow();

    assertThat(GuardianVoiceAudio.isMp4Container(aac)).isTrue();
    assertThat(aac.length).isLessThan(wav.length / 5);
    assertThat(new String(restored, 0, 4, StandardCharsets.US_ASCII)).isEqualTo("RIFF");
    assertThat(new String(restored, 8, 4, StandardCharsets.US_ASCII)).isEqualTo("WAVE");
  }

  @Test
  @DisplayName("음성이 아닌 바이트는 던지지 않고 빈 값 — 압축 실패로 음성 저장이 막히지 않게")
  void invalidInput_isEmpty() {
    assertThat(codec.toAac(new byte[]{1, 2, 3, 4})).isEmpty();
    assertThat(codec.toWav(new byte[0])).isEmpty();
  }

  @Test
  @DisplayName("ffmpeg 가 없으면 던지지 않고 빈 값")
  void missingCommand_isEmpty() {
    FfmpegSpeechAudioCodec missing = new FfmpegSpeechAudioCodec("elum-no-such-ffmpeg", Duration.ofSeconds(1));

    assertThat(missing.toAac(sineWav(1))).isEmpty();
  }

  private static boolean isFfmpegInstalled() {
    try {
      return new ProcessBuilder(FfmpegSpeechAudioCodec.DEFAULT_COMMAND, "-version").start().waitFor() == 0;
    } catch (Exception e) {
      return false;
    }
  }

  /// 44.1kHz 16비트 모노 사인파 WAV (운영 음성과 같은 형식)
  private static byte[] sineWav(int seconds) {
    int sampleRate = 44_100;
    int sampleCount = sampleRate * seconds;
    ByteBuffer pcm = ByteBuffer.allocate(sampleCount * 2).order(ByteOrder.LITTLE_ENDIAN);
    for (int i = 0; i < sampleCount; i++) {
      pcm.putShort((short) (Math.sin(2 * Math.PI * 440 * i / sampleRate) * 8_000));
    }
    ByteBuffer header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN);
    header.put("RIFF".getBytes(StandardCharsets.US_ASCII)).putInt(36 + pcm.capacity())
      .put("WAVE".getBytes(StandardCharsets.US_ASCII)).put("fmt ".getBytes(StandardCharsets.US_ASCII))
      .putInt(16).putShort((short) 1).putShort((short) 1).putInt(sampleRate).putInt(sampleRate * 2)
      .putShort((short) 2).putShort((short) 16)
      .put("data".getBytes(StandardCharsets.US_ASCII)).putInt(pcm.capacity());
    ByteArrayOutputStream out = new ByteArrayOutputStream();
    out.writeBytes(header.array());
    out.writeBytes(pcm.array());
    return out.toByteArray();
  }
}
