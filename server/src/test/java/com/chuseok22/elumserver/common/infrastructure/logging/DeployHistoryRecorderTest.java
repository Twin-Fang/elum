package com.chuseok22.elumserver.common.infrastructure.logging;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.stream.IntStream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class DeployHistoryRecorderTest {

  @TempDir
  Path tempDir;

  private final InstanceInfo info = new InstanceInfo("green", "8086", "2.19.0", Instant.EPOCH);
  private final Clock clock = Clock.fixed(Instant.parse("2026-10-08T00:12:03.456Z"), ZoneId.of("Asia/Seoul"));

  @Test
  @DisplayName("한 줄에 시각·인스턴스·버전·포트·이벤트를 남긴다")
  void appendsLine() throws IOException {
    Path file = tempDir.resolve("nested/deploy-history.log");
    DeployHistoryRecorder recorder = new DeployHistoryRecorder(file, info, clock);

    recorder.onStarted();
    recorder.onReady();

    assertThat(Files.readAllLines(file)).containsExactly(
      "2026-10-08T09:12:03+09:00 green 2.19.0 8086 STARTED",
      "2026-10-08T09:12:03+09:00 green 2.19.0 8086 READY"
    );
  }

  @Test
  @DisplayName("READY 때 1000줄을 넘으면 최근 1000줄만 남긴다")
  void trimsOldLines() throws IOException {
    Path file = tempDir.resolve("deploy-history.log");
    List<String> old = IntStream.range(0, 1200).mapToObj(i -> "line" + i).toList();
    Files.write(file, old, StandardCharsets.UTF_8);

    new DeployHistoryRecorder(file, info, clock).onReady();

    List<String> lines = Files.readAllLines(file);
    assertThat(lines).hasSize(DeployHistoryRecorder.MAX_LINES);
    assertThat(lines.get(lines.size() - 1)).endsWith("READY");
  }

  @Test
  @DisplayName("쓸 수 없는 위치여도 예외를 던지지 않는다 — 기동을 막지 않는다")
  void neverThrows() throws IOException {
    Path blocker = Files.writeString(tempDir.resolve("blocker"), "file");
    DeployHistoryRecorder recorder = new DeployHistoryRecorder(blocker.resolve("deploy-history.log"), info, clock);

    recorder.onStarted();
    recorder.onReady();
  }

  @Test
  @DisplayName("포트가 없으면 '-', 인스턴스는 정규화한다")
  void normalizesInfo() {
    InstanceInfo local = new InstanceInfo("../x", "", null, Instant.EPOCH);

    assertThat(local.instance()).isEqualTo("local");
    assertThat(local.port()).isEqualTo("-");
    assertThat(local.version()).isEqualTo("unknown");
  }

  @Test
  @DisplayName("0초여도 초를 빼지 않는다")
  void keepsZeroSeconds() throws IOException {
    Path file = tempDir.resolve("deploy-history.log");
    Clock onTheMinute = Clock.fixed(Instant.parse("2026-10-08T02:47:00Z"), ZoneId.of("Asia/Seoul"));

    new DeployHistoryRecorder(file, info, onTheMinute).onStarted();

    assertThat(Files.readAllLines(file)).containsExactly("2026-10-08T11:47:00+09:00 green 2.19.0 8086 STARTED");
  }
}
