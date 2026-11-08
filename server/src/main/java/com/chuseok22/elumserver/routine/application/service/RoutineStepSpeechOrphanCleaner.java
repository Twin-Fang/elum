package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineStepSpeechStorage;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import java.time.Clock;
import java.time.Duration;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 쓰지 않는 단계 음성 파일 정리 (#1212): 카드가 쓰는 열쇠 > 오래된 저장 파일 > 열쇠에 없는 파일 삭제
 * 카드를 지우는 경로(일과 삭제·보호자 관계 정리·탈퇴 등)가 여러 곳이라, 어느 경로로 지워져도 여기서 정리
 */
@Slf4j
@Component
public class RoutineStepSpeechOrphanCleaner {

  // 만든 지 이보다 덜 된 파일은 건너뜀 (저장 직후 열쇠 갱신 전 파일 보호)
  static final Duration PROTECTED_RECENT_FILE_AGE = Duration.ofHours(1);

  private final RoutineStepRepository routineStepRepository;
  private final RoutineStepSpeechStorage routineStepSpeechStorage;
  private final MigrationLock migrationLock;
  private final Clock clock;

  @Autowired
  public RoutineStepSpeechOrphanCleaner(
    RoutineStepRepository routineStepRepository, RoutineStepSpeechStorage routineStepSpeechStorage,
    MigrationLock migrationLock
  ) {
    this(routineStepRepository, routineStepSpeechStorage, migrationLock, Clock.systemUTC());
  }

  RoutineStepSpeechOrphanCleaner(
    RoutineStepRepository routineStepRepository, RoutineStepSpeechStorage routineStepSpeechStorage,
    MigrationLock migrationLock, Clock clock
  ) {
    this.routineStepRepository = routineStepRepository;
    this.routineStepSpeechStorage = routineStepSpeechStorage;
    this.migrationLock = migrationLock;
    this.clock = clock;
  }

  // 하루 1번 (배포 뒤 15분에 첫 실행)
  @Scheduled(fixedDelayString = "PT24H", initialDelayString = "PT15M")
  public void clean() {
    if (migrationLock.isBlockingScheduledJob("RoutineStepSpeechOrphanCleaner")) {
      return;
    }
    try {
      // 카드가 쓰는 열쇠 (0건이면 조회 이상으로 보고 아무것도 지우지 않음)
      Set<String> referencedKeys = new HashSet<>(routineStepRepository.findAllSpeechPaths());
      if (referencedKeys.isEmpty()) {
        log.warn("[routine speech] orphan clean skipped : reason=no referenced keys");
        return;
      }
      // 오래된 파일 중 열쇠에 없는 것만 삭제
      List<String> candidateKeys = routineStepSpeechStorage.listKeysModifiedBefore(
        clock.instant().minus(PROTECTED_RECENT_FILE_AGE));
      List<String> orphanKeys = candidateKeys.stream().filter(key -> !referencedKeys.contains(key)).toList();
      orphanKeys.forEach(routineStepSpeechStorage::delete);
      log.info("[routine speech] orphans deleted : count={}, scanned={}, referenced={}",
        orphanKeys.size(), candidateKeys.size(), referencedKeys.size());
    } catch (Exception e) {
      // 조회·목록 실패면 지우지 않고 다음 주기에 다시 (스케줄러 스레드 보호)
      log.warn("[routine speech] orphan clean failed : cause={}", e.getClass().getSimpleName(), e);
    }
  }
}
