package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 저장된 png 카드 그림 > webp 전환 (#1219). 열쇠와 파일이 어긋나면 카드 그림이 사라진다.
 */
@ExtendWith(MockitoExtension.class)
class RoutineImageCompactorTest {

  private static final String PNG_KEY = "batch-1/1.png";
  private static final String WEBP_KEY = "batch-1/1.webp";

  @Mock private RoutineStepRepository repository;
  @Mock private RoutineImageStorage storage;
  @Mock private MigrationLock migrationLock;

  private RoutineImageCompactor compactor;

  @BeforeEach
  void setUp() {
    compactor = new RoutineImageCompactor(repository, storage, migrationLock);
  }

  @Test
  @DisplayName("webp 사본을 만들고 같은 그림을 쓰는 카드(복제 포함)를 모두 바꾼 뒤 옛 png 를 지운다")
  void compactOne_replacesAllCardsThenDeletesPng() {
    when(storage.saveWebpCopy(PNG_KEY)).thenReturn(Optional.of(WEBP_KEY));
    when(repository.replaceImagePath(PNG_KEY, WEBP_KEY)).thenReturn(2);

    assertThat(compactor.compactOne(PNG_KEY)).isTrue();

    verify(storage).delete(PNG_KEY);
    verify(storage, never()).delete(WEBP_KEY);
  }

  @Test
  @DisplayName("그새 그림이 바뀌어 교체가 0건이면 새 사본만 지운다")
  void compactOne_noCardReplaced_deletesCopyOnly() {
    when(storage.saveWebpCopy(PNG_KEY)).thenReturn(Optional.of(WEBP_KEY));
    when(repository.replaceImagePath(PNG_KEY, WEBP_KEY)).thenReturn(0);

    assertThat(compactor.compactOne(PNG_KEY)).isFalse();

    verify(storage).delete(WEBP_KEY);
    verify(storage, never()).delete(PNG_KEY);
  }

  @Test
  @DisplayName("다시 그리기 후보가 아직 가리키는 png 는 지우지 않는다 — 보호자가 보는 후보가 깨지지 않게")
  void compactOne_candidateStillUsesPng_keepsPng() {
    when(storage.saveWebpCopy(PNG_KEY)).thenReturn(Optional.of(WEBP_KEY));
    when(repository.replaceImagePath(PNG_KEY, WEBP_KEY)).thenReturn(1);
    when(repository.existsByImageCandidatePath(PNG_KEY)).thenReturn(true);

    compactor.compactOne(PNG_KEY);

    verify(storage, never()).delete(anyString());
  }

  @Test
  @DisplayName("변환에 실패한 그림은 열쇠를 그대로 두고, 다음 주기에는 건너뛴다 — 한 장 때문에 뒤가 막히지 않게")
  void compact_failedKeyIsSkippedNextRound() {
    when(repository.findPngImagePaths(any())).thenReturn(List.of(PNG_KEY));
    when(storage.saveWebpCopy(PNG_KEY)).thenReturn(Optional.empty());

    compactor.compact();
    compactor.compact();

    verify(storage, times(1)).saveWebpCopy(PNG_KEY);
    verify(repository, never()).replaceImagePath(anyString(), anyString());
  }

  @Test
  @DisplayName("서버 이전 잠금 중이면 건너뛴다")
  void compact_skipsWhileMigrationLocked() {
    when(migrationLock.isBlockingScheduledJob("RoutineImageCompactor")).thenReturn(true);

    compactor.compact();

    verify(repository, never()).findPngImagePaths(any());
  }
}
