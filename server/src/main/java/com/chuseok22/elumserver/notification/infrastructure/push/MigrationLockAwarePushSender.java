package com.chuseok22.elumserver.notification.infrastructure.push;

import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * 이전 잠금 중에는 푸시를 보내지 않는 발송기 (#1053): 잠김 > 보내지 않고 FAILED, 아니면 실제 발송기에 맡김
 * 발송 지점 한 곳에서 막아 예약 알림·비동기 리스너가 잠금 전에 쌓은 알림도 새 서버와 중복되지 않게 한다
 */
@Slf4j
@RequiredArgsConstructor
public class MigrationLockAwarePushSender implements PushSender {

  private final PushSender delegate;
  private final MigrationLock migrationLock;

  @Override
  public PushResult send(PushMessage message) {
    if (migrationLock.isLocked()) {
      log.info("[notification push] skipped : migration lock");
      return PushResult.FAILED;
    }
    return delegate.send(message);
  }
}
