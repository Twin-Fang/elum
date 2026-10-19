package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.infrastructure.repository.NoticeSeenRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationSettingRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.PushDeviceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 알림 데이터 정리: 회원 탈퇴·완전 삭제, 이룸이 프로필 삭제
 * 다른 도메인(member)은 저장소가 아니라 이 서비스를 거쳐 지움
 */
@Service
@RequiredArgsConstructor
public class NotificationCleanupService {

  private final NotificationRepository notificationRepository;
  private final PushDeviceRepository pushDeviceRepository;
  private final NotificationSettingRepository notificationSettingRepository;
  private final NoticeSeenRepository noticeSeenRepository;

  /// 회원의 알림·푸시 기기·설정·공지 확인 기록 삭제 (행이 없어도 무방)
  @Transactional
  public void deleteAllOf(String memberId) {
    notificationRepository.deleteAllByRecipientMemberId(memberId);
    pushDeviceRepository.deleteAllByMemberId(memberId);
    notificationSettingRepository.deleteById(memberId);
    noticeSeenRepository.deleteById(memberId);
  }

  /// 이룸이 프로필에 딸린 알림 삭제
  @Transactional
  public void deleteAllOfProfile(String profileId) {
    notificationRepository.deleteAllByProfileId(profileId);
  }
}
