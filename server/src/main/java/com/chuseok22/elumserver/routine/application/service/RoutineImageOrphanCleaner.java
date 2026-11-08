package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import java.time.Clock;
import java.time.Duration;
import java.util.HashSet;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 쓰지 않는 카드 그림 정리 (#1216): 카드가 쓰는 그림·후보 열쇠 > 오래된 파일 중 열쇠에 없는 것 삭제
 * 일과를 지우는 경로가 여러 곳이라, 어느 경로로 지워져도 여기서 정리 (음성은 RoutineStepSpeechOrphanCleaner)
 */
@Slf4j
@Component
public class RoutineImageOrphanCleaner {

  // 만든 지 이보다 덜 된 파일은 건너뜀 (생성 중·카드 저장 전 그림 보호)
  static final Duration PROTECTED_RECENT_FILE_AGE = Duration.ofDays(1);

  private final RoutineStepRepository routineStepRepository;
  private final RoutineImageStorage routineImageStorage;
  private final MigrationLock migrationLock;
  private final Clock clock;

  @Autowired
  public RoutineImageOrphanCleaner(
    RoutineStepRepository routineStepRepository, RoutineImageStorage routineImageStorage, MigrationLock migrationLock
  ) {
    this(routineStepRepository, routineImageStorage, migrationLock, Clock.systemUTC());
  }

  RoutineImageOrphanCleaner(
    RoutineStepRepository routineStepRepository, RoutineImageStorage routineImageStorage,
    MigrationLock migrationLock, Clock clock
  ) {
    this.routineStepRepository = routineStepRepository;
    this.routineImageStorage = routineImageStorage;
    this.migrationLock = migrationLock;
    this.clock = clock;
  }

  // 하루 1번 (배포 뒤 20분에 첫 실행)
  @Scheduled(fixedDelayString = "PT24H", initialDelayString = "PT20M")
  public void clean() {
    if (migrationLock.isBlockingScheduledJob("RoutineImageOrphanCleaner")) {
      return;
    }
    try {
      // 카드가 쓰는 열쇠: 그림 + 다시 그리기 후보 (0건이면 조회 이상으로 보고 지우지 않음)
      Set<String> referencedKeys = new HashSet<>(routineStepRepository.findAllImagePaths());
      referencedKeys.addAll(routineStepRepository.findAllImageCandidatePaths());
      if (referencedKeys.isEmpty()) {
        log.warn("[routine image] orphan clean skipped : reason=no referenced keys");
        return;
      }
      int deletedCount = routineImageStorage.deleteUnreferenced(
        referencedKeys, clock.instant().minus(PROTECTED_RECENT_FILE_AGE));
      log.info("[routine image] orphans deleted : count={}, referenced={}", deletedCount, referencedKeys.size());
    } catch (Exception e) {
      // 조회·목록 실패면 지우지 않고 다음 주기에 다시 (스케줄러 스레드 보호)
      log.warn("[routine image] orphan clean failed : cause={}", e.getClass().getSimpleName(), e);
    }
  }
}
