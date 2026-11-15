package com.chuseok22.elumserver.license.infrastructure.scheduler;

import com.chuseok22.elumserver.license.application.service.refund.StoreRefundRecheckService;
import com.chuseok22.elumserver.license.core.StoreRefundCheckTrigger;
import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 매일 스토어 환불 재확인 (#1428): 켜짐(STORE_REFUND_RECHECK_ENABLED) 확인 > 두 스토어 재확인 > 실행 기록
 * 기본 꺼짐. 스토어 키가 없으면 서비스가 그 스토어를 건너뛰고 사유를 기록
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class StoreRefundRecheckScheduler {

  private final StoreRefundRecheckService recheckService;
  private final MigrationLock migrationLock;

  // 새벽 4시 50분(한국 시각): 사용이 적은 때, 탈퇴 계정 정리(4:30) 뒤
  @Scheduled(cron = "${elum.store.refund-recheck-cron:0 50 4 * * *}", zone = "Asia/Seoul")
  public void run() {
    if (migrationLock.isBlockingScheduledJob("StoreRefundRecheckScheduler") || !recheckService.isScheduleEnabled()) {
      return;
    }
    try {
      recheckService.runAll(StoreRefundCheckTrigger.SCHEDULED, null);
    } catch (RuntimeException e) {
      log.error("[refund recheck] scheduled run failed : cause={}", e.getClass().getSimpleName(), e);
    }
  }
}
