package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 저장된 png 카드 그림 > webp 전환 (#1219): webp 사본 저장 > 같은 열쇠를 쓰는 카드 모두 교체 > 옛 png 삭제
 * 2분마다 최대 20장. 다시 그리기 후보는 바꾸지 않음 (보호자가 보는 중 열쇠가 바뀌면 적용이 실패)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineImageCompactor {

  // 한 주기 최대 장수 (실측 변환 1장 약 0.3초 > 20장 약 6초)
  static final int COMPACT_BATCH_SIZE = 20;

  private final RoutineStepRepository routineStepRepository;
  private final RoutineImageStorage routineImageStorage;
  private final MigrationLock migrationLock;

  // 전환에 실패한 열쇠 (서버가 켜져 있는 동안 다시 시도하지 않음, 뒤 그림이 막히지 않게)
  private final Set<String> failedImageKeys = ConcurrentHashMap.newKeySet();

  @Scheduled(fixedDelayString = "PT2M", initialDelayString = "PT4M")
  public void compact() {
    if (migrationLock.isBlockingScheduledJob("RoutineImageCompactor")) {
      return;
    }
    try {
      List<String> pngImageKeys = routineStepRepository
        .findPngImagePaths(PageRequest.of(0, COMPACT_BATCH_SIZE + failedImageKeys.size())).stream()
        .filter(key -> !failedImageKeys.contains(key))
        .limit(COMPACT_BATCH_SIZE)
        .toList();
      if (pngImageKeys.isEmpty()) {
        return;
      }
      int compactedCount = 0;
      for (String pngImageKey : pngImageKeys) {
        if (compactOne(pngImageKey)) {
          compactedCount++;
        }
      }
      log.info("[routine image] compacted : count={}, scanned={}, failedTotal={}",
        compactedCount, pngImageKeys.size(), failedImageKeys.size());
    } catch (Exception e) {
      // 조회 실패해도 다음 주기에 다시 (스케줄러 스레드 보호)
      log.warn("[routine image] compact failed : cause={}", e.getClass().getSimpleName(), e);
    }
  }

  /// 1장 전환. 교체가 0건이면(그새 그림이 바뀜) 새 사본을 버림
  boolean compactOne(String pngImageKey) {
    Optional<String> webpImageKey = routineImageStorage.saveWebpCopy(pngImageKey);
    if (webpImageKey.isEmpty()) {
      failedImageKeys.add(pngImageKey);
      log.warn("[routine image] compact skipped : reason=copy failed");
      return false;
    }
    if (routineStepRepository.replaceImagePath(pngImageKey, webpImageKey.get()) == 0) {
      routineImageStorage.delete(webpImageKey.get());
      return false;
    }
    // 옛 png 삭제 (다시 그리기 후보가 아직 가리키면 남김, 정리 작업이 나중에 처리)
    if (!routineStepRepository.existsByImageCandidatePath(pngImageKey)) {
      routineImageStorage.delete(pngImageKey);
    }
    return true;
  }
}
