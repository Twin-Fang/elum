package com.chuseok22.elumserver.migration;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 규칙: @Scheduled 가 있는 파일은 이전 잠금을 확인한다 (#1053)
 * 깨지면: 새로 만든 예약 작업이 전환 뒤 친구 서버에서 돌아 알림이 두 번 가거나 덤프 뒤 DB 가 바뀐다
 */
class MigrationLockScheduledJobRuleTest {

  // 테스트는 server/ 에서 돈다
  private static final Path MAIN_SOURCE = Path.of("src/main/java");
  private static final String SCHEDULED_ANNOTATION = "@Scheduled(";
  private static final String LOCK_CHECK_CALL = "isBlockingScheduledJob(";

  @Test
  @DisplayName("모든 예약 작업 파일이 isBlockingScheduledJob 을 부른다")
  void everyScheduledJob_checksMigrationLock() throws IOException {
    List<Path> violations;
    try (Stream<Path> files = Files.walk(MAIN_SOURCE)) {
      violations = files
        .filter(path -> path.toString().endsWith(".java"))
        .filter(path -> contains(path, SCHEDULED_ANNOTATION) && !contains(path, LOCK_CHECK_CALL))
        .toList();
    }
    assertThat(violations).as("예약 작업 첫 줄에 migrationLock.isBlockingScheduledJob(...) 이 없는 파일").isEmpty();
  }

  @Test
  @DisplayName("규칙이 실제로 예약 작업을 찾는다 (0개면 검사가 헛돈다)")
  void scheduledJobs_areFound() throws IOException {
    try (Stream<Path> files = Files.walk(MAIN_SOURCE)) {
      assertThat(files.filter(path -> path.toString().endsWith(".java"))
        .filter(path -> contains(path, SCHEDULED_ANNOTATION))
        .count()).isGreaterThanOrEqualTo(4);
    }
  }

  private static boolean contains(Path file, String text) {
    try {
      return Files.readString(file).contains(text);
    } catch (IOException e) {
      throw new IllegalStateException(file.toString(), e);
    }
  }
}
