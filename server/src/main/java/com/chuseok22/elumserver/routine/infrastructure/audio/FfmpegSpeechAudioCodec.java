package com.chuseok22.elumserver.routine.infrastructure.audio;

import com.chuseok22.elumserver.common.infrastructure.media.FfmpegConverter;
import com.chuseok22.elumserver.routine.core.GuardianVoiceAudio;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Component;

/**
 * ffmpeg 로 단계 음성 변환: WAV > AAC(m4a) 저장용, AAC > WAV 옛 앱 응답용 (#1211)
 */
@Component
public class FfmpegSpeechAudioCodec implements SpeechAudioCodec {

  static final String DEFAULT_COMMAND = FfmpegConverter.DEFAULT_COMMAND;
  // 변환 1건 상한 (실측 0.07~0.19초, 즉석 합성 대기 여유 1초 안)
  static final Duration DEFAULT_TIMEOUT = Duration.ofSeconds(5);
  // AAC 40kbps · 24kHz · 모노 (말소리 기준 wav 의 1/16, #1211 실측). faststart = 재생 정보(moov) 앞에 둠
  private static final List<String> AAC_OPTIONS =
    List.of("-ac", "1", "-ar", "24000", "-c:a", "aac", "-b:a", "40k", "-movflags", "+faststart");
  // 16비트 PCM WAV (옛 앱의 wav 머리 검사 통과용)
  private static final List<String> WAV_OPTIONS = List.of("-c:a", "pcm_s16le");

  private final FfmpegConverter ffmpegConverter;

  public FfmpegSpeechAudioCodec() {
    this(DEFAULT_COMMAND, DEFAULT_TIMEOUT);
  }

  FfmpegSpeechAudioCodec(String command, Duration timeout) {
    this.ffmpegConverter = new FfmpegConverter(command, timeout);
  }

  @Override
  public Optional<byte[]> toAac(byte[] wav) {
    return ffmpegConverter.convert(wav, ".wav", ".m4a", AAC_OPTIONS, GuardianVoiceAudio::isMp4Container);
  }

  @Override
  public Optional<byte[]> toWav(byte[] aac) {
    return ffmpegConverter.convert(aac, ".m4a", ".wav", WAV_OPTIONS, FfmpegSpeechAudioCodec::isWav);
  }

  /// WAV 머리 `RIFF....WAVE`
  private static boolean isWav(byte[] audio) {
    return audio.length >= 12
      && "RIFF".equals(new String(audio, 0, 4, StandardCharsets.US_ASCII))
      && "WAVE".equals(new String(audio, 8, 4, StandardCharsets.US_ASCII));
  }
}
