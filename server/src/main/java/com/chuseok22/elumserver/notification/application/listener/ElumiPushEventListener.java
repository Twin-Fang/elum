package com.chuseok22.elumserver.notification.application.listener;

import com.chuseok22.elumserver.common.infrastructure.config.AsyncConfig;
import com.chuseok22.elumserver.notification.application.service.ElumiPushDispatcher;
import com.chuseok22.elumserver.notification.core.event.RoutineSentEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * 이룸이 기기 푸시 이벤트 수신: 일과 보냄 > 일과 도착 알림
 * 커밋 뒤 + 별도 스레드 (보호자 알림 기록과 따로 돌아 한쪽 실패가 다른 쪽을 막지 않음). 실패는 로그만
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ElumiPushEventListener {

  private final ElumiPushDispatcher elumiPushDispatcher;

  @Async(AsyncConfig.NOTIFICATION_EXECUTOR)
  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  public void onRoutineSent(RoutineSentEvent event) {
    // 보낸 쪽이 이룸이 기기면(다시하기) 자기 행동이라 알리지 않음
    if (event.actorMemberId() == null) {
      return;
    }
    try {
      elumiPushDispatcher.dispatchRoutineArrived(event.profileId(), event.routineId());
    } catch (RuntimeException exception) {
      log.warn("[elumi push] failed routine arrived : {}", exception.getClass().getSimpleName());
    }
  }
}
