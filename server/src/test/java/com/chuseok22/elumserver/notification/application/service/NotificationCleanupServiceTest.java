package com.chuseok22.elumserver.notification.application.service;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import com.chuseok22.elumserver.notification.infrastructure.repository.NoticeSeenRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationSettingRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.PushDeviceRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class NotificationCleanupServiceTest {

  @Mock
  private NotificationRepository notificationRepository;
  @Mock
  private PushDeviceRepository pushDeviceRepository;
  @Mock
  private NotificationSettingRepository notificationSettingRepository;
  @Mock
  private NoticeSeenRepository noticeSeenRepository;

  @InjectMocks
  private NotificationCleanupService notificationCleanupService;

  @Test
  @DisplayName("탈퇴 시 알림·푸시 기기·설정·공지 확인 기록을 모두 지운다 — 남으면 탈퇴한 사람에게 푸시가 간다")
  void deleteAllOf_removesNotificationsDevicesSettingsAndSeen() {
    notificationCleanupService.deleteAllOf("member-1");

    verify(notificationRepository).deleteAllByRecipientMemberId("member-1");
    verify(pushDeviceRepository).deleteAllByMemberId("member-1");
    verify(notificationSettingRepository).deleteById("member-1");
    verify(noticeSeenRepository).deleteById("member-1");
  }

  @Test
  @DisplayName("이룸이 프로필을 지우면 그 프로필의 알림만 지운다 — 기기·설정은 회원 것이라 건드리지 않는다")
  void deleteAllOfProfile_removesOnlyProfileNotifications() {
    notificationCleanupService.deleteAllOfProfile("profile-1");

    verify(notificationRepository).deleteAllByProfileId("profile-1");
    verifyNoInteractions(pushDeviceRepository, notificationSettingRepository, noticeSeenRepository);
  }
}
