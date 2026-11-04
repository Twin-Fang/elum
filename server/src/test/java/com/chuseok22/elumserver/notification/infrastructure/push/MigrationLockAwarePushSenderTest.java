package com.chuseok22.elumserver.notification.infrastructure.push;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 이전 잠금 중 푸시 멈춤 (#1053)
 * 깨지면: 전환 뒤 같은 알림이 친구 서버와 새 서버에서 두 번 간다
 */
class MigrationLockAwarePushSenderTest {

  private final PushSender delegate = mock(PushSender.class);
  private final MigrationLock migrationLock = mock(MigrationLock.class);
  private final PushSender sender = new MigrationLockAwarePushSender(delegate, migrationLock);
  private final PushMessage message = mock(PushMessage.class);

  @Test
  @DisplayName("잠겼으면 보내지 않고 FAILED")
  void locked_doesNotSend_returnsFailed() {
    when(migrationLock.isLocked()).thenReturn(true);

    assertThat(sender.send(message)).isEqualTo(PushResult.FAILED);
    verify(delegate, never()).send(any());
  }

  @Test
  @DisplayName("잠기지 않았으면 실제 발송기 결과를 그대로")
  void unlocked_delegates() {
    when(migrationLock.isLocked()).thenReturn(false);
    when(delegate.send(message)).thenReturn(PushResult.SENT);

    assertThat(sender.send(message)).isEqualTo(PushResult.SENT);
  }
}
