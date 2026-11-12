package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.core.AdminMessageRoute;
import com.chuseok22.elumserver.notification.core.NotificationDraft;
import com.chuseok22.elumserver.notification.core.NotificationTime;
import com.chuseok22.elumserver.notification.infrastructure.entity.AdminMessage;
import com.chuseok22.elumserver.notification.infrastructure.entity.NotificationSetting;
import com.chuseok22.elumserver.notification.infrastructure.repository.AdminMessageRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationSettingRepository;
import com.chuseok22.elumserver.notification.infrastructure.repository.PushDeviceRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 운영자 알림 (#1273): 받는 사람의 푸시 도달 미리 계산, 보내기(내용 저장 > 알림함 기록 > 푸시)
 * 받는 사람 고르기·상한·야간 막기·관리자 기록은 부르는 쪽(관리자) 몫
 */
@Slf4j
@Service
public class AdminMessageService {

  // 한 번에 묻는 회원 id 수 (in 절 길이 제한)
  private static final int MEMBER_ID_CHUNK_SIZE = 500;

  private final AdminMessageRepository adminMessageRepository;
  private final NotificationSettingRepository notificationSettingRepository;
  private final PushDeviceRepository pushDeviceRepository;
  private final NotificationRecorder notificationRecorder;
  private final PushDispatcher pushDispatcher;
  private final Clock clock;

  @Autowired
  public AdminMessageService(AdminMessageRepository adminMessageRepository,
    NotificationSettingRepository notificationSettingRepository, PushDeviceRepository pushDeviceRepository,
    NotificationRecorder notificationRecorder, PushDispatcher pushDispatcher) {
    this(adminMessageRepository, notificationSettingRepository, pushDeviceRepository, notificationRecorder,
      pushDispatcher, Clock.system(NotificationTime.ZONE_ID));
  }

  AdminMessageService(AdminMessageRepository adminMessageRepository,
    NotificationSettingRepository notificationSettingRepository, PushDeviceRepository pushDeviceRepository,
    NotificationRecorder notificationRecorder, PushDispatcher pushDispatcher, Clock clock) {
    this.adminMessageRepository = adminMessageRepository;
    this.notificationSettingRepository = notificationSettingRepository;
    this.pushDeviceRepository = pushDeviceRepository;
    this.notificationRecorder = notificationRecorder;
    this.pushDispatcher = pushDispatcher;
    this.clock = clock;
  }

  /// 받는 사람 > 푸시 켠 사람 수·그 사람들의 보호자 기기 수 (알림 전체 끔은 빼고 셈, 이룸이 기기 제외)
  public AdminMessageReach reachOf(Collection<String> memberIds) {
    List<String> distinctMemberIds = memberIds == null ? List.of() : List.copyOf(new HashSet<>(memberIds));
    Set<String> pushOffMemberIds = new HashSet<>();
    int deviceCount = 0;
    for (List<String> chunk : chunksOf(distinctMemberIds)) {
      notificationSettingRepository.findAllById(chunk).stream()
        .filter(setting -> !setting.isAllEnabled())
        .map(NotificationSetting::getMemberId)
        .forEach(pushOffMemberIds::add);
      deviceCount += (int) pushDeviceRepository.findAllByMemberIdInAndLinkIdIsNull(chunk).stream()
        .filter(device -> !pushOffMemberIds.contains(device.getMemberId()))
        .count();
    }
    return new AdminMessageReach(distinctMemberIds.size(), distinctMemberIds.size() - pushOffMemberIds.size(),
      deviceCount);
  }

  /**
   * 보내기: 내용 저장 > 받는 사람마다 알림함 기록 (사람별 독립 커밋) > 푸시 (전체 끔 제외) > 결과 수
   * 트랜잭션 없음: FCM 호출 동안 DB 연결을 잡지 않음 (PushDispatcher 와 같음)
   */
  public AdminMessageSendResult send(String title, String body, AdminMessageRoute route,
    Collection<String> recipientMemberIds) {
    AdminMessage message = new AdminMessage();
    message.setTitle(title);
    message.setBody(body);
    message.setRoute(route);
    AdminMessage saved = adminMessageRepository.save(message);

    List<RecordedNotification> recorded = notificationRecorder.record(
      NotificationDraft.adminMessage(saved.getId(), LocalDateTime.now(clock)), List.copyOf(new HashSet<>(recipientMemberIds)));
    AdminMessageDelivery delivery = pushDispatcher.dispatchAdminMessage(recorded, saved);
    log.info("[admin message] sent : messageId={}, recorded={}, sentDevices={}, failedDevices={}",
      saved.getId(), recorded.size(), delivery.sentDeviceCount(), delivery.failedDeviceCount());
    return new AdminMessageSendResult(saved.getId(), recorded.size(), delivery.sentDeviceCount(),
      delivery.failedDeviceCount());
  }

  private static List<List<String>> chunksOf(List<String> memberIds) {
    List<List<String>> chunks = new ArrayList<>();
    for (int start = 0; start < memberIds.size(); start += MEMBER_ID_CHUNK_SIZE) {
      chunks.add(memberIds.subList(start, Math.min(start + MEMBER_ID_CHUNK_SIZE, memberIds.size())));
    }
    return chunks;
  }
}
