package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import com.chuseok22.elumserver.notification.core.NotificationDraft;
import com.chuseok22.elumserver.notification.core.NotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.AdminMessage;
import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationSetting;
import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import com.chuseok22.elumserver.notification.infrastructure.repository.AdminMessageRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationSettingRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.PushDeviceRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/// 미리 계산이 알림 끈 회원·그 기기를 세면 운영자가 실제보다 많이 간다고 오해하고, 기록 묶음 키가 겹치면 두 번째 알림이 알림함에 안 남는다
class AdminMessageServiceTest {

  private final AdminMessageRepository adminMessageRepository = mock(AdminMessageRepository.class);
  private final NotificationSettingRepository notificationSettingRepository = mock(NotificationSettingRepository.class);
  private final PushDeviceRepository pushDeviceRepository = mock(PushDeviceRepository.class);
  private final NotificationRecorder notificationRecorder = mock(NotificationRecorder.class);
  private final PushDispatcher pushDispatcher = mock(PushDispatcher.class);
  private AdminMessageService service;

  @BeforeEach
  void setUp() {
    service = new AdminMessageService(adminMessageRepository, notificationSettingRepository, pushDeviceRepository,
      notificationRecorder, pushDispatcher, Clock.fixed(Instant.parse("2026-11-12T05:00:00Z"), ZoneId.of("Asia/Seoul")));
  }

  @Test
  @DisplayName("도달 계산: 전체 끔 회원은 알림 켠 수와 기기 수에서 빠지고, 설정 행 없는 회원은 켠 것으로 센다")
  void reachOf_excludesPushOffMembersAndTheirDevices() {
    NotificationSetting pushOff = new NotificationSetting();
    pushOff.setMemberId("m-off");
    pushOff.setAllEnabled(false);
    NotificationSetting pushOn = new NotificationSetting();
    pushOn.setMemberId("m-on");
    when(notificationSettingRepository.findAllById(anyCollection())).thenReturn(List.of(pushOff, pushOn));
    when(pushDeviceRepository.findAllByMemberIdInAndLinkIdIsNull(anyCollection()))
      .thenReturn(List.of(device("m-on"), device("m-on"), device("m-off"), device("m-no-row")));

    AdminMessageReach reach = service.reachOf(List.of("m-on", "m-off", "m-no-row", "m-no-device", "m-on"));

    assertThat(reach).isEqualTo(new AdminMessageReach(4, 3, 3));
  }

  @Test
  @DisplayName("보내기: 저장한 알림 id 로 묶음 키를 만들어 받는 사람마다 기록하고, 기록 수·기기 결과를 돌려준다")
  void send_recordsEachRecipientUnderMessageGroupKey() {
    when(adminMessageRepository.save(any())).thenAnswer(invocation -> {
      AdminMessage saved = invocation.getArgument(0);
      saved.setId("msg-1");
      return saved;
    });
    List<RecordedNotification> recorded = List.of(new RecordedNotification("n1", "m1", 1, true));
    when(notificationRecorder.record(any(), anyCollection())).thenReturn(recorded);
    when(pushDispatcher.dispatchAdminMessage(any(), any())).thenReturn(new AdminMessageDelivery(2, 1));

    AdminMessageSendResult result = service.send("제목", "본문", AdminMessageRoute.HOME, List.of("m1", "m2"));

    ArgumentCaptor<NotificationDraft> draft = ArgumentCaptor.forClass(NotificationDraft.class);
    verify(notificationRecorder).record(draft.capture(), anyCollection());
    assertThat(draft.getValue().type()).isEqualTo(NotificationType.ADMIN_MESSAGE);
    assertThat(draft.getValue().groupKey()).isEqualTo("ADMIN_MESSAGE:msg-1");
    assertThat(draft.getValue().targetId()).isEqualTo("msg-1");
    assertThat(result).isEqualTo(new AdminMessageSendResult("msg-1", 1, 2, 1));
  }

  private static PushDevice device(String memberId) {
    PushDevice device = new PushDevice();
    device.setMemberId(memberId);
    device.setToken("token-" + memberId);
    return device;
  }
}
