package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.link.application.service.DeviceLinkService;
import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import com.chuseok22.elumserver.notification.infrastructure.push.PushResult;
import com.chuseok22.elumserver.notification.infrastructure.push.PushSender;
import com.chuseok22.elumserver.notification.infrastructure.repository.PushDeviceRepository;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 이룸이 기기 푸시: 살아 있는 연결 > 그 연결의 기기 > 순차 발송 > 무효 토큰 삭제
 * 알림 행·보호자 알림 설정과 무관 (이룸이는 알림 목록이 없고, 끄기는 기기 설정 몫). 한 기기 실패는 로그만
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ElumiPushDispatcher {

  private final DeviceLinkService deviceLinkService;
  private final PushDeviceRepository pushDeviceRepository;
  private final PushMessageFactory pushMessageFactory;
  private final PushSender pushSender;

  /** 보호자가 일과를 보냄 > 그 이룸이에 연결된 기기 전부에 "새 일과가 도착했어요" */
  // 트랜잭션 없음: FCM 호출 동안 DB 연결을 잡지 않음 (PushDispatcher 와 같은 이유)
  public void dispatchRoutineArrived(String profileId, String routineId) {
    List<String> liveLinkIds = deviceLinkService.liveLinkIdsOf(profileId);
    if (liveLinkIds.isEmpty()) {
      return;
    }
    // 끊긴 연결의 남은 토큰은 대상에서 빠짐 (살아 있는 연결 ID 로만 조회)
    List<PushDevice> devices = pushDeviceRepository.findAllByLinkIdIn(liveLinkIds);
    int sentCount = 0;
    for (PushDevice device : devices) {
      try {
        PushResult pushResult = pushSender.send(
          pushMessageFactory.createElumiRoutineArrived(device, profileId, routineId));
        if (pushResult == PushResult.SENT) {
          sentCount++;
        } else if (pushResult == PushResult.INVALID_TOKEN) {
          pushDeviceRepository.deleteByToken(device.getToken());
          log.info("[elumi push] invalid token removed : platform={}", device.getPlatform());
        }
      } catch (RuntimeException exception) {
        // 한 기기 실패가 다른 기기 발송을 막지 않음
        log.warn("[elumi push] failed : {}", exception.getClass().getSimpleName());
      }
    }
    log.info("[elumi push] routine arrived : devices={} sent={}", devices.size(), sentCount);
  }
}
