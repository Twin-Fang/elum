package com.chuseok22.elumserver.common.infrastructure.media;

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

/**
 * ffmpeg 파일 변환 공통: 임시 폴더에 입력 쓰기 > ffmpeg 실행 > 출력 머리 확인 > 임시 폴더 삭제 (#1211, #1219)
 * 어떤 실패도 던지지 않음 (빈 값). 파이프 대신 파일 사용 (m4a 는 파이프 출력이 안 됨)
 */
@Slf4j
public final class FfmpegConverter {

  // 운영 이미지에 apk 로 설치 (server/Dockerfile)
  public static final String DEFAULT_COMMAND = "ffmpeg";
  // 실패 로그에 남길 ffmpeg 출력 최대 길이
  private static final int MAX_ERROR_LOG_CHARS = 200;

  private final String command;
  private final Duration timeout;

  public FfmpegConverter(String command, Duration timeout) {
    this.command = command;
    this.timeout = timeout;
  }

  /**
   * 입력 바이트 > ffmpeg 옵션으로 변환한 바이트. 실패·시간 초과·출력 머리 불일치면 빈 값
   */
  public Optional<byte[]> convert(
    byte[] input, String inputExtension, String outputExtension, List<String> options, Predicate<byte[]> isValidOutput
  ) {
    if (input == null || input.length == 0) {
      return Optional.empty();
    }
    Path workDirectory = null;
    try {
      workDirectory = Files.createTempDirectory("elum-ffmpeg-");
      Path inputFile = Files.write(workDirectory.resolve("in" + inputExtension), input);
      Path outputFile = workDirectory.resolve("out" + outputExtension);
      Path logFile = workDirectory.resolve("ffmpeg.log");
      if (!runFfmpeg(inputFile, outputFile, logFile, options)) {
        return Optional.empty();
      }
      byte[] convertedBytes = Files.readAllBytes(outputFile);
      if (!isValidOutput.test(convertedBytes)) {
        log.warn("[ffmpeg] rejected result : format={}, bytes={}", outputExtension, convertedBytes.length);
        return Optional.empty();
      }
      return Optional.of(convertedBytes);
    } catch (IOException e) {
      log.warn("[ffmpeg] failed : format={}, cause={}", outputExtension, e.getClass().getSimpleName());
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
      log.warn("[ffmpeg] timed out : timeoutMs={}", timeout.toMillis());
      return false;
    }
    if (process.exitValue() != 0) {
      log.warn("[ffmpeg] exited : code={}, error={}", process.exitValue(), errorSummaryOf(logFile));
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

  private static void deleteQuietly(Path directory) {
    if (directory == null) {
      return;
    }
    try (Stream<Path> paths = Files.walk(directory)) {
      paths.sorted(Comparator.reverseOrder()).forEach(path -> path.toFile().delete());
    } catch (IOException e) {
      log.warn("[ffmpeg] temp cleanup failed : path={}", directory);
    }
  }
}
