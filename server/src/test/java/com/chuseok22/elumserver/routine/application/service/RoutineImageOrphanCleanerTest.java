package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.properties.RoutineProperties;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.LocalFileRoutineImageStorage;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.Mock;
import org.mockito.Mockito;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 쓰지 않는 카드 그림 정리 (#1216). 쓰는 그림을 지우면 카드 그림이 사라지고 다시 그리려면 돈이 든다.
 */
@ExtendWith(MockitoExtension.class)
class RoutineImageOrphanCleanerTest {

  private static final Instant NOW = Instant.parse("2026-11-08T03:00:00Z");
  private static final Instant OLD = NOW.minusSeconds(3 * 86_400);
  private static final Instant RECENT = NOW.minusSeconds(3_600);

  @TempDir
  Path tempDir;

  @Mock private RoutineStepRepository repository;
  @Mock private MigrationLock migrationLock;

  private RoutineImageOrphanCleaner cleaner;

  @BeforeEach
  void setUp() {
    RoutineImageStorage storage = new LocalFileRoutineImageStorage(new RoutineProperties(tempDir.toString()));
    cleaner = new RoutineImageOrphanCleaner(repository, storage, migrationLock, Clock.fixed(NOW, ZoneOffset.UTC));
  }

  @Test
  @DisplayName("카드가 쓰는 그림·후보는 남기고, 지워진 일과 그림과 빈 폴더는 지운다")
  void clean_deletesOnlyUnreferenced() throws Exception {
    write("batch-live/1.png", OLD);
    write("step-1/ai-candidate.png", OLD);
    write("batch-deleted/1.png", OLD);
    write("batch-live/2-old.png", OLD);
    when(repository.findAllImagePaths()).thenReturn(List.of("batch-live/1.png"));
    when(repository.findAllImageCandidatePaths()).thenReturn(List.of("step-1/ai-candidate.png"));

    cleaner.clean();

    assertThat(tempDir.resolve("batch-live/1.png")).exists();
    assertThat(tempDir.resolve("step-1/ai-candidate.png")).exists();
    assertThat(tempDir.resolve("batch-live/2-old.png")).doesNotExist();
    assertThat(tempDir.resolve("batch-deleted")).doesNotExist();
  }

  @Test
  @DisplayName("옛 형식(저장 폴더 전체 경로) 열쇠가 가리키는 그림도 지우지 않는다")
  void clean_keepsLegacyFullPathKeys() throws Exception {
    write("batch-old/1.png", OLD);
    String legacyKey = tempDir.resolve("batch-old/1.png").toString();
    when(repository.findAllImagePaths()).thenReturn(List.of(legacyKey));
    when(repository.findAllImageCandidatePaths()).thenReturn(List.of());

    cleaner.clean();

    assertThat(tempDir.resolve("batch-old/1.png")).exists();
  }

  @Test
  @DisplayName("하루 안 된 그림과 보호자 녹음 폴더는 남긴다 — 만드는 중인 일과 그림·녹음이 사라지지 않게")
  void clean_keepsRecentFilesAndGuardianVoices() throws Exception {
    write("batch-live/1.png", OLD);
    write("batch-new/1.png", RECENT);
    write("guardian-voice/member-1/voice.m4a", OLD);
    when(repository.findAllImagePaths()).thenReturn(List.of("batch-live/1.png"));
    when(repository.findAllImageCandidatePaths()).thenReturn(List.of());

    cleaner.clean();

    assertThat(tempDir.resolve("batch-new/1.png")).exists();
    assertThat(tempDir.resolve("guardian-voice/member-1/voice.m4a")).exists();
  }

  @Test
  @DisplayName("카드 열쇠가 0건이거나 조회가 실패하면 아무것도 지우지 않는다 — 조회 이상 때 저장소 전체를 지우지 않게")
  void clean_noKeysOrQueryFails_deletesNothing() throws Exception {
    write("batch-1/1.png", OLD);
    when(repository.findAllImagePaths()).thenReturn(List.of());
    when(repository.findAllImageCandidatePaths()).thenReturn(List.of());

    cleaner.clean();

    assertThat(tempDir.resolve("batch-1/1.png")).exists();

    RoutineImageStorage mockStorage = Mockito.mock(RoutineImageStorage.class);
    when(repository.findAllImagePaths()).thenThrow(new IllegalStateException("db down"));
    new RoutineImageOrphanCleaner(repository, mockStorage, migrationLock, Clock.fixed(NOW, ZoneOffset.UTC)).clean();
    verify(mockStorage, never()).deleteUnreferenced(any(), any());
  }

  @Test
  @DisplayName("서버 이전 잠금 중이면 건너뛴다")
  void clean_skipsWhileMigrationLocked() {
    when(migrationLock.isBlockingScheduledJob("RoutineImageOrphanCleaner")).thenReturn(true);

    cleaner.clean();

    verify(repository, never()).findAllImagePaths();
  }

  private void write(String key, Instant modifiedAt) throws Exception {
    Path file = tempDir.resolve(key);
    Files.createDirectories(file.getParent());
    Files.write(file, new byte[]{1});
    Files.setLastModifiedTime(file, FileTime.from(modifiedAt));
  }
}
