package com.chuseok22.elumserver.routine.infrastructure.audio;

import com.chuseok22.elumserver.routine.core.GuardianVoiceAudio;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.TimeUnit;
import java.util.function.Predicate;
import java.util.stream.Stream;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * ffmpeg 프로세스로 음성 변환: 임시 폴더에 입력 쓰기 > ffmpeg 실행 > 출력 머리 확인 > 임시 폴더 삭제 (#1211)
 * 파이프 대신 파일 사용 (m4a 는 끝에서 앞으로 되돌아 쓰는 형식이라 파이프 출력이 안 됨)
 */
@Slf4j
@Component
public class FfmpegSpeechAudioCodec implements SpeechAudioCodec {

  // 운영 이미지에 apk 로 설치 (server/Dockerfile)
  static final String DEFAULT_COMMAND = "ffmpeg";
  // 변환 1건 상한 (실측 0.07~0.19초, 즉석 합성 대기 여유 1초 안)
  static final Duration DEFAULT_TIMEOUT = Duration.ofSeconds(5);
  // AAC 40kbps · 24kHz · 모노 (말소리 기준 wav 의 1/16, #1211 실측). faststart = 재생 정보(moov) 앞에 둠
  private static final List<String> AAC_OPTIONS =
    List.of("-ac", "1", "-ar", "24000", "-c:a", "aac", "-b:a", "40k", "-movflags", "+faststart");
  // 16비트 PCM WAV (옛 앱의 wav 머리 검사 통과용)
  private static final List<String> WAV_OPTIONS = List.of("-c:a", "pcm_s16le");
  // 실패 로그에 남길 ffmpeg 출력 최대 길이
  private static final int MAX_ERROR_LOG_CHARS = 200;

  private final String command;
  private final Duration timeout;

  public FfmpegSpeechAudioCodec() {
    this(DEFAULT_COMMAND, DEFAULT_TIMEOUT);
  }

  FfmpegSpeechAudioCodec(String command, Duration timeout) {
    this.command = command;
    this.timeout = timeout;
  }

  @Override
  public Optional<byte[]> toAac(byte[] wav) {
    return convert(wav, ".wav", ".m4a", AAC_OPTIONS, GuardianVoiceAudio::isMp4Container);
  }

  @Override
  public Optional<byte[]> toWav(byte[] aac) {
    return convert(aac, ".m4a", ".wav", WAV_OPTIONS, FfmpegSpeechAudioCodec::isWav);
  }

  /// 입력 쓰기 > 실행 > 출력 확인. 어떤 실패도 빈 값 (임시 폴더는 성공·실패 공통 삭제)
  private Optional<byte[]> convert(
    byte[] input, String inputExtension, String outputExtension, List<String> options, Predicate<byte[]> isValidOutput
  ) {
    if (input == null || input.length == 0) {
      return Optional.empty();
    }
    Path workDirectory = null;
    try {
      workDirectory = Files.createTempDirectory("elum-speech-");
      Path inputFile = Files.write(workDirectory.resolve("in" + inputExtension), input);
      Path outputFile = workDirectory.resolve("out" + outputExtension);
      Path logFile = workDirectory.resolve("ffmpeg.log");
      if (!runFfmpeg(inputFile, outputFile, logFile, options)) {
        return Optional.empty();
      }
      byte[] convertedAudio = Files.readAllBytes(outputFile);
      if (!isValidOutput.test(convertedAudio)) {
        log.warn("[speech codec] rejected result : format={}, bytes={}", outputExtension, convertedAudio.length);
        return Optional.empty();
      }
      return Optional.of(convertedAudio);
    } catch (IOException e) {
      log.warn("[speech codec] failed : format={}, cause={}", outputExtension, e.getClass().getSimpleName());
      return Optional.empty();
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
      return Optional.empty();
    } finally {
      deleteQuietly(workDirectory);
    }
  }

  /// ffmpeg 실행 > 정상 종료면 true. 시간 초과는 강제 종료 후 false
  private boolean runFfmpeg(Path inputFile, Path outputFile, Path logFile, List<String> options)
    throws IOException, InterruptedException {
    List<String> arguments = new ArrayList<>(List.of(command, "-nostdin", "-v", "error", "-y", "-i", inputFile.toString()));
    arguments.addAll(options);
    arguments.add(outputFile.toString());
    Process process = new ProcessBuilder(arguments)
      .redirectErrorStream(true)
      .redirectOutput(logFile.toFile())
      .start();
    if (!process.waitFor(timeout.toMillis(), TimeUnit.MILLISECONDS)) {
      process.destroyForcibly();
      log.warn("[speech codec] timed out : timeoutMs={}", timeout.toMillis());
      return false;
    }
    if (process.exitValue() != 0) {
      log.warn("[speech codec] ffmpeg exited : code={}, error={}", process.exitValue(), errorSummaryOf(logFile));
      return false;
    }
    return true;
  }

  private static String errorSummaryOf(Path logFile) {
    try {
      String summary = Files.readString(logFile, StandardCharsets.UTF_8).strip().replaceAll("[\\r\\n]+", " ");
      return summary.length() > MAX_ERROR_LOG_CHARS ? summary.substring(0, MAX_ERROR_LOG_CHARS) : summary;
    } catch (IOException e) {
      return "";
    }
  }

  /// WAV 머리 `RIFF....WAVE`
  private static boolean isWav(byte[] audio) {
    return audio.length >= 12
      && "RIFF".equals(new String(audio, 0, 4, StandardCharsets.US_ASCII))
      && "WAVE".equals(new String(audio, 8, 4, StandardCharsets.US_ASCII));
  }

  private static void deleteQuietly(Path directory) {
    if (directory == null) {
      return;
    }
    try (Stream<Path> paths = Files.walk(directory)) {
      paths.sorted(Comparator.reverseOrder()).forEach(path -> path.toFile().delete());
    } catch (IOException e) {
      log.warn("[speech codec] temp cleanup failed : path={}", directory);
    }
  }
}
