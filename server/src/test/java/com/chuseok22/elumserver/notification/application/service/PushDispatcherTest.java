package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.notification.core.NotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.Notification;
import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationSetting;
import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import com.chuseok22.elumserver.notification.infrastructure.push.PushMessage;
import com.chuseok22.elumserver.notification.infrastructure.push.PushResult;
import com.chuseok22.elumserver.notification.infrastructure.push.PushSender;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationSettingRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.PushDeviceRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/// 설정을 무시하면 끈 알림이 오고, 무효 토큰을 안 지우면 계속 실패하며, 한 기기 예외가 다른 기기를 막는다
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class PushDispatcherTest {

  @Mock
  private NotificationRepository notificationRepository;
  @Mock
  private NotificationSettingRepository notificationSettingRepository;
  @Mock
  private PushDeviceRepository pushDeviceRepository;
  @Mock
  private PushSender pushSender;

  private PushDispatcher dispatcher;
  private final RecordedNotification recorded = new RecordedNotification("n1", "m1", 1, true);

  @BeforeEach
  void setUp() {
    dispatcher = new PushDispatcher(notificationRepository, notificationSettingRepository, pushDeviceRepository,
      new PushMessageFactory(), pushSender);
    Notification notification = new Notification();
    notification.setId("n1");
    notification.setType(NotificationType.ROUTINE_COMPLETED);
    notification.setGroupKey("g1");
    when(notificationRepository.findById("n1")).thenReturn(Optional.of(notification));
    when(notificationSettingRepository.findById("m1")).thenReturn(Optional.empty());
    when(pushSender.send(any())).thenReturn(PushResult.SENT);
  }

  @Test
  @DisplayName("전체 끔이면 종류별이 켜져 있어도 보내지 않는다")
  void allDisabled_sendsNothing() {
    NotificationSetting setting = new NotificationSetting();
    setting.setAllEnabled(false);
    when(notificationSettingRepository.findById("m1")).thenReturn(Optional.of(setting));
    when(pushDeviceRepository.findAllByMemberIdIn(any())).thenReturn(List.of(device("t1")));

    dispatcher.dispatch(List.of(recorded), NotificationType.ROUTINE_COMPLETED);

    verify(pushSender, never()).send(any());
  }

  @Test
  @DisplayName("해당 종류가 꺼져 있으면 보내지 않는다")
  void typeDisabled_sendsNothing() {
    NotificationSetting setting = new NotificationSetting();
    setting.setRoutineCompletedEnabled(false);
    when(notificationSettingRepository.findById("m1")).thenReturn(Optional.of(setting));
    when(pushDeviceRepository.findAllByMemberIdIn(any())).thenReturn(List.of(device("t1")));

    dispatcher.dispatch(List.of(recorded), NotificationType.ROUTINE_COMPLETED);

    verify(pushSender, never()).send(any());
  }

  @Test
  @DisplayName("설정 행이 없으면 모든 기기에 보낸다")
  void noSettingRow_sendsToAllDevices() {
    when(pushDeviceRepository.findAllByMemberIdIn(any())).thenReturn(List.of(device("t1"), device("t2")));

    dispatcher.dispatch(List.of(recorded), NotificationType.ROUTINE_COMPLETED);

    verify(pushSender, org.mockito.Mockito.times(2)).send(any(PushMessage.class));
  }

  @Test
  @DisplayName("무효 토큰은 기기를 지우고 나머지 기기는 계속 보낸다")
  void invalidToken_deletesDevice_andContinuesOthers() {
    when(pushDeviceRepository.findAllByMemberIdIn(any())).thenReturn(List.of(device("t1"), device("t2")));
    when(pushSender.send(any())).thenReturn(PushResult.INVALID_TOKEN, PushResult.SENT);

    dispatcher.dispatch(List.of(recorded), NotificationType.ROUTINE_COMPLETED);

    verify(pushDeviceRepository).deleteByToken("t1");
    verify(pushDeviceRepository, never()).deleteByToken("t2");
    verify(pushSender, org.mockito.Mockito.times(2)).send(any());
  }

  @Test
  @DisplayName("발송기가 예외를 던져도 밖으로 전파하지 않는다")
  void senderThrows_doesNotPropagate() {
    when(pushDeviceRepository.findAllByMemberIdIn(any())).thenReturn(List.of(device("t1")));
    when(pushSender.send(any())).thenThrow(new IllegalStateException("boom"));

    assertThatCode(() -> dispatcher.dispatch(List.of(recorded), NotificationType.ROUTINE_COMPLETED))
      .doesNotThrowAnyException();
  }

  private PushDevice device(String token) {
    PushDevice device = new PushDevice();
    device.setMemberId("m1");
    device.setToken(token);
    device.setLocale(AppLocale.KO);
    return device;
  }
}
