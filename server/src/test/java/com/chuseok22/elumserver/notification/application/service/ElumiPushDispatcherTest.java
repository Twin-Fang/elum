package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.link.application.service.DeviceLinkService;
import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import com.chuseok22.elumserver.notification.infrastructure.push.PushMessage;
import com.chuseok22.elumserver.notification.infrastructure.push.PushResult;
import com.chuseok22.elumserver.notification.infrastructure.push.PushSender;
import com.chuseok22.elumserver.notification.infrastructure.repository.PushDeviceRepository;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/// 끊긴 연결에 알림이 가거나, 일과 제목이 잠금 화면에 뜨거나, 무효 토큰이 쌓이면 이룸이 기기 알림이 틀린다
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class ElumiPushDispatcherTest {

  @Mock
  private DeviceLinkService deviceLinkService;
  @Mock
  private PushDeviceRepository pushDeviceRepository;
  @Mock
  private PushSender pushSender;

  private ElumiPushDispatcher dispatcher;

  @BeforeEach
  void setUp() {
    dispatcher = new ElumiPushDispatcher(deviceLinkService, pushDeviceRepository, new PushMessageFactory(), pushSender);
  }

  @Test
  @DisplayName("살아 있는 연결의 기기에만 이룸이 채널로 보낸다 (일과 제목 없음)")
  void dispatchRoutineArrived_sendsOnlyToLiveLinkDevices() {
    when(deviceLinkService.liveLinkIdsOf("p1")).thenReturn(List.of("link-1"));
    when(pushDeviceRepository.findAllByLinkIdIn(List.of("link-1"))).thenReturn(List.of(device("t1")));
    when(pushSender.send(any())).thenReturn(PushResult.SENT);

    dispatcher.dispatchRoutineArrived("p1", "r1");

    ArgumentCaptor<PushMessage> captor = ArgumentCaptor.forClass(PushMessage.class);
    verify(pushSender).send(captor.capture());
    PushMessage message = captor.getValue();
    assertThat(message.token()).isEqualTo("t1");
    assertThat(message.body()).isEqualTo("새 일과가 도착했어요");
    assertThat(message.androidChannelId()).isEqualTo("elumi_routines");
    assertThat(message.data()).containsEntry("type", "ELUMI_ROUTINE_ARRIVED").containsEntry("routineId", "r1");
  }

  @Test
  @DisplayName("살아 있는 연결이 없으면 기기를 찾지도 보내지도 않는다")
  void dispatchRoutineArrived_noLiveLink_sendsNothing() {
    when(deviceLinkService.liveLinkIdsOf("p1")).thenReturn(List.of());

    dispatcher.dispatchRoutineArrived("p1", "r1");

    verify(pushDeviceRepository, never()).findAllByLinkIdIn(any());
    verify(pushSender, never()).send(any());
  }

  @Test
  @DisplayName("무효 토큰은 지우고, 한 기기 실패가 다음 기기 발송을 막지 않는다")
  void dispatchRoutineArrived_invalidTokenRemoved_failureIsolated() {
    when(deviceLinkService.liveLinkIdsOf("p1")).thenReturn(List.of("link-1", "link-2"));
    when(pushDeviceRepository.findAllByLinkIdIn(any())).thenReturn(List.of(device("t1"), device("t2"), device("t3")));
    when(pushSender.send(any()))
      .thenReturn(PushResult.INVALID_TOKEN)
      .thenThrow(new IllegalStateException("fcm down"))
      .thenReturn(PushResult.SENT);

    dispatcher.dispatchRoutineArrived("p1", "r1");

    verify(pushDeviceRepository).deleteByToken("t1");
    verify(pushSender, times(3)).send(any());
  }

  private PushDevice device(String token) {
    PushDevice device = new PushDevice();
    device.setToken(token);
    device.setLinkId("link-1");
    device.setLocale(AppLocale.KO);
    return device;
  }
}
