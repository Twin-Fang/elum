package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.DeployHistoryResponse.Deployment;
import java.nio.file.Path;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class DeployHistoryServiceTest {

  private static final Instant NOW = Instant.parse("2026-10-08T03:00:00Z"); // 12:00 KST

  @TempDir
  Path tempDir;

  private DeployHistoryService service(String me) {
    return new DeployHistoryService(new LogFileLocator(tempDir.toString(), me));
  }

  @Test
  @DisplayName("정상 교대: 새 green 은 실행 중(현재), 옛 blue 는 종료")
  void normalSwitch() {
    List<Deployment> result = service("green").judge(List.of(
      "2026-10-07T18:00:00+09:00 blue 2.18.0 8085 STARTED",
      "2026-10-07T18:00:40+09:00 blue 2.18.0 8085 READY",
      "2026-10-08T09:00:00+09:00 green 2.19.0 8086 STARTED",
      "2026-10-08T09:00:50+09:00 green 2.19.0 8086 READY",
      "2026-10-08T09:01:10+09:00 blue 2.18.0 8085 STOPPED"
    ), NOW);

    assertThat(result).extracting(Deployment::instance).containsExactly("green", "blue");
    assertThat(result.get(0).status()).isEqualTo("RUNNING");
    assertThat(result.get(0).current()).isTrue();
    assertThat(result.get(1).status()).isEqualTo("STOPPED");
    assertThat(result.get(1).current()).isFalse();
  }

  @Test
  @DisplayName("옛 컨테이너가 STOPPED 없이 지워져도 다른 배포가 READY 면 종료로 본다")
  void replacedWithoutStopped() {
    List<Deployment> result = service("green").judge(List.of(
      "2026-10-07T18:00:00+09:00 blue 2.18.0 8085 STARTED",
      "2026-10-07T18:00:40+09:00 blue 2.18.0 8085 READY",
      "2026-10-08T09:00:00+09:00 green 2.19.0 8086 STARTED",
      "2026-10-08T09:00:50+09:00 green 2.19.0 8086 READY"
    ), NOW);

    assertThat(result.get(1).status()).isEqualTo("STOPPED");
  }

  @Test
  @DisplayName("READY 없이 같은 색이 다시 뜨거나 STOPPED 되면 실패")
  void failedDeployments() {
    List<Deployment> result = service("blue").judge(List.of(
      "2026-10-07T18:00:00+09:00 blue 2.18.0 8085 STARTED",
      "2026-10-07T18:00:40+09:00 blue 2.18.0 8085 READY",
      "2026-10-08T09:00:00+09:00 green 2.19.0 8086 STARTED",
      "2026-10-08T09:02:00+09:00 green 2.19.0 8086 STOPPED",
      "2026-10-08T10:00:00+09:00 green 2.19.1 8086 STARTED",
      "2026-10-08T11:00:00+09:00 green 2.19.2 8086 STARTED"
    ), NOW);

    assertThat(result).extracting(Deployment::version).containsExactly("2.19.2", "2.19.1", "2.19.0", "2.18.0");
    assertThat(result).extracting(Deployment::status).containsExactly("FAILED", "FAILED", "FAILED", "RUNNING");
    assertThat(result.get(3).current()).isTrue();
  }

  @Test
  @DisplayName("최근에 떠서 아직 READY 가 없으면 기동 중")
  void starting() {
    List<Deployment> result = service("blue").judge(List.of(
      "2026-10-08T11:59:00+09:00 green 2.19.0 8086 STARTED"
    ), NOW);

    assertThat(result.get(0).status()).isEqualTo("STARTING");
  }

  @Test
  @DisplayName("깨진 줄·모르는 이벤트는 무시한다")
  void ignoresBrokenLines() {
    List<Deployment> result = service("green").judge(List.of(
      "",
      "garbage",
      "어제 green 2.19.0 8086 STARTED",
      "2026-10-08T09:00:00+09:00 green 2.19.0 8086 STARTED",
      "2026-10-08T09:00:10+09:00 green 2.19.0 8086 PAUSED",
      "2026-10-08T09:00:50+09:00 green 2.19.0 8086 READY"
    ), NOW);

    assertThat(result).hasSize(1);
    assertThat(result.get(0).status()).isEqualTo("RUNNING");
  }

  @Test
  @DisplayName("이력 파일이 없으면 빈 목록")
  void missingFile() {
    assertThat(service("green").list(NOW).deployments()).isEmpty();
  }
}
