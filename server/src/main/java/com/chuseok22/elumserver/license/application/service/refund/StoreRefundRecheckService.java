package com.chuseok22.elumserver.license.application.service.refund;

import com.chuseok22.elumserver.license.application.service.store.StoreSubscriptionSettings;
import com.chuseok22.elumserver.license.core.StoreRefundCheckFailureReason;
import com.chuseok22.elumserver.license.core.StoreRefundCheckTrigger;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StoreRefundCheckRun;
import com.chuseok22.elumserver.license.infrastructure.repository.StoreRefundCheckRunRepository;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.function.Consumer;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

/**
 * 스토어 환불 재확인 (#1428): 알림을 놓친 환불을 Google·Apple 에 다시 물어 크레딧 꾸러미·Pro 회수, 스토어별 실행 기록 1줄
 * 자동(매일)·관리자 "지금 확인" 공통. 같은 서버 안 동시 실행은 순서대로 (회수는 반복해도 한 번만)
 */
@Slf4j
@Service
public class StoreRefundRecheckService {

  // 관리자 화면 최근 실행 수 (스토어 2개 x 1주)
  static final int RECENT_RUN_COUNT = 14;
  // 이 시간 안에 성공 실행이 없으면 경고 (매일 1회 + 여유 2시간)
  static final Duration SUCCESSFUL_RUN_MAXIMUM_INTERVAL = Duration.ofHours(26);

  private final GoogleRefundRecheck googleRecheck;
  private final AppleRefundRecheck appleRecheck;
  private final StoreRefundCheckRunRepository runRepository;
  private final StoreSubscriptionSettings settings;
  private final Clock clock;

  @Autowired
  public StoreRefundRecheckService(
    GoogleRefundRecheck googleRecheck, AppleRefundRecheck appleRecheck, StoreRefundCheckRunRepository runRepository,
    StoreSubscriptionSettings settings
  ) {
    this(googleRecheck, appleRecheck, runRepository, settings, Clock.systemDefaultZone());
  }

  StoreRefundRecheckService(
    GoogleRefundRecheck googleRecheck, AppleRefundRecheck appleRecheck, StoreRefundCheckRunRepository runRepository,
    StoreSubscriptionSettings settings, Clock clock
  ) {
    this.googleRecheck = googleRecheck;
    this.appleRecheck = appleRecheck;
    this.runRepository = runRepository;
    this.settings = settings;
    this.clock = clock;
  }

  /// 두 스토어 1회씩 (Google > Apple). 한 스토어 실패가 다른 스토어를 막지 않음
  public synchronized List<StoreRefundCheckRun> runAll(StoreRefundCheckTrigger trigger, String requestedBy) {
    return List.of(
      runOne(SubscriptionSource.GOOGLE_IAP, trigger, requestedBy, googleRecheck::run),
      runOne(SubscriptionSource.APPLE_IAP, trigger, requestedBy, appleRecheck::run));
  }

  /// 매일 재확인 켜짐 (설정 STORE_REFUND_RECHECK_ENABLED)
  public boolean isScheduleEnabled() {
    return settings.isRefundRecheckEnabled();
  }

  /// 최근 실행 기록 (두 스토어 섞어 최신순)
  public List<StoreRefundCheckRun> recentRuns() {
    return runRepository.findAllByOrderByStartedAtDesc(PageRequest.of(0, RECENT_RUN_COUNT));
  }

  /**
   * 경고할 스토어: 매일 재확인이 켜졌고 결제가 켜진 스토어 중 마지막 실행 실패 또는 26시간 안에 성공 없음
   * 꺼져 있으면 빈 목록 (돌지 않는 게 정상)
   */
  public List<SubscriptionSource> storesNeedingAttention() {
    List<SubscriptionSource> stores = new ArrayList<>();
    if (!settings.isRefundRecheckEnabled()) {
      return stores;
    }
    LocalDateTime successfulSince = LocalDateTime.now(clock).minus(SUCCESSFUL_RUN_MAXIMUM_INTERVAL);
    if (settings.isGoogleEnabled() && needsAttention(SubscriptionSource.GOOGLE_IAP, successfulSince)) {
      stores.add(SubscriptionSource.GOOGLE_IAP);
    }
    if (settings.isAppleEnabled() && needsAttention(SubscriptionSource.APPLE_IAP, successfulSince)) {
      stores.add(SubscriptionSource.APPLE_IAP);
    }
    return stores;
  }

  // 실행 1회: 시작 > 스토어 단계 > 끝 시각·저장 (성공·실패 공통)
  private StoreRefundCheckRun runOne(
    SubscriptionSource store, StoreRefundCheckTrigger trigger, String requestedBy, Consumer<StoreRefundCheckRun> storeStep
  ) {
    StoreRefundCheckRun run = StoreRefundCheckRun.start(store, trigger, requestedBy, LocalDateTime.now(clock));
    try {
      storeStep.accept(run);
    } catch (RuntimeException e) {
      log.error("[refund recheck] failed : store={}, cause={}", store, e.getClass().getSimpleName(), e);
      run.recordFailure(StoreRefundCheckFailureReason.UNEXPECTED_ERROR);
    } finally {
      run.finish(LocalDateTime.now(clock));
      saveRun(run);
    }
    log.info("[refund recheck] done : store={}, trigger={}, voided={}, checked={}, refunded={}, revoked={}, failure={}",
      store, trigger, run.getVoidedCount(), run.getCheckedCount(), run.getRefundedCount(), run.getRevokedCount(),
      run.getFailureReason());
    return run;
  }

  // 기록 저장 실패는 회수 결과를 되돌리지 않음 (회수는 건마다 이미 커밋됨)
  private void saveRun(StoreRefundCheckRun run) {
    try {
      runRepository.save(run);
    } catch (RuntimeException e) {
      log.error("[refund recheck] run record save failed : store={}", run.getStore(), e);
    }
  }

  private boolean needsAttention(SubscriptionSource store, LocalDateTime successfulSince) {
    Optional<StoreRefundCheckRun> latest = runRepository.findFirstByStoreOrderByStartedAtDesc(store);
    if (latest.isPresent() && !latest.get().isSucceeded()) {
      return true;
    }
    return !runRepository.existsByStoreAndFailureReasonIsNullAndStartedAtAfter(store, successfulSince);
  }
}
