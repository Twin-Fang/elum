package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.properties.TtsProperties;
import com.chuseok22.elumserver.routine.core.SpeechAudioFormat;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.LocalFileRoutineStepSpeechStorage;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineStepSpeechStorage;
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
 * 쓰지 않는 단계 음성 정리 (#1212). 잘못 지우면 카드 음성이 사라지고, 안 지우면 저장소가 계속 찬다.
 */
@ExtendWith(MockitoExtension.class)
class RoutineStepSpeechOrphanCleanerTest {

  private static final Instant NOW = Instant.parse("2026-11-08T03:00:00Z");
  private static final Instant OLD = NOW.minusSeconds(2 * 3600);
  private static final Instant RECENT = NOW.minusSeconds(60);

  @TempDir
  Path tempDir;

  @Mock private RoutineStepRepository repository;
  @Mock private MigrationLock migrationLock;

  private RoutineStepSpeechStorage storage;
  private RoutineStepSpeechOrphanCleaner cleaner;

  @BeforeEach
  void setUp() {
    storage = new LocalFileRoutineStepSpeechStorage(new TtsProperties(true, tempDir.toString()));
    cleaner = new RoutineStepSpeechOrphanCleaner(repository, storage, migrationLock, Clock.fixed(NOW, ZoneOffset.UTC));
  }

  @Test
  @DisplayName("카드가 쓰지 않는 오래된 파일과 빈 단계 폴더를 지우고, 쓰는 파일은 남긴다")
  void clean_deletesOnlyUnreferencedOldFiles() throws Exception {
    String usedKey = save("step-live", "used", OLD);
    String deletedStepKey = save("step-deleted", "old", OLD);
    String staleTextKey = save("step-live", "stale", OLD);
    when(repository.findAllSpeechPaths()).thenReturn(List.of(usedKey));

    cleaner.clean();

    assertThat(storage.read(usedKey)).isPresent();
    assertThat(storage.read(deletedStepKey)).isEmpty();
    assertThat(storage.read(staleTextKey)).isEmpty();
    assertThat(tempDir.resolve("step-deleted")).doesNotExist();
    assertThat(tempDir.resolve("step-live")).exists();
  }

  @Test
  @DisplayName("만든 지 1시간 안 된 파일은 열쇠에 없어도 남긴다 — 저장 직후 열쇠 갱신 전 음성을 지우지 않게")
  void clean_keepsRecentFiles() throws Exception {
    String usedKey = save("step-live", "used", OLD);
    String justSavedKey = save("step-new", "new", RECENT);
    when(repository.findAllSpeechPaths()).thenReturn(List.of(usedKey));

    cleaner.clean();

    assertThat(storage.read(justSavedKey)).isPresent();
  }

  @Test
  @DisplayName("카드 열쇠가 0건으로 읽히면 아무것도 지우지 않는다 — 조회 이상 때 저장소 전체를 지우지 않게")
  void clean_noReferencedKeys_deletesNothing() throws Exception {
    String key = save("step-1", "a", OLD);
    when(repository.findAllSpeechPaths()).thenReturn(List.of());

    cleaner.clean();

    assertThat(storage.read(key)).isPresent();
  }

  @Test
  @DisplayName("카드 열쇠 조회가 실패하면 아무것도 지우지 않는다")
  void clean_queryFails_deletesNothing() {
    RoutineStepSpeechStorage mockStorage = Mockito.mock(RoutineStepSpeechStorage.class);
    when(repository.findAllSpeechPaths()).thenThrow(new IllegalStateException("db down"));

    new RoutineStepSpeechOrphanCleaner(repository, mockStorage, migrationLock, Clock.fixed(NOW, ZoneOffset.UTC)).clean();

    verify(mockStorage, never()).delete(anyString());
    verify(mockStorage, never()).listKeysModifiedBefore(any());
  }

  @Test
  @DisplayName("서버 이전 잠금 중이면 건너뛴다")
  void clean_skipsWhileMigrationLocked() {
    when(migrationLock.isBlockingScheduledJob("RoutineStepSpeechOrphanCleaner")).thenReturn(true);

    cleaner.clean();

    verify(repository, never()).findAllSpeechPaths();
  }

  private String save(String stepId, String textHash, Instant modifiedAt) throws Exception {
    String key = storage.save(stepId, textHash, new byte[]{1}, SpeechAudioFormat.AAC);
    Files.setLastModifiedTime(tempDir.resolve(key), FileTime.from(modifiedAt));
    return key;
  }
}
