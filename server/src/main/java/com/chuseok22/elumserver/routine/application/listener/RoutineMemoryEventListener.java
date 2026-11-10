package com.chuseok22.elumserver.routine.application.listener;

import com.chuseok22.elumserver.common.infrastructure.config.AsyncConfig;
import com.chuseok22.elumserver.routine.application.service.RoutineMemoryExtractor;
import com.chuseok22.elumserver.routine.core.RoutineMemoryExtractionRequestedEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/// 확정 이벤트 수신: 커밋 뒤 + 별도 스레드에서 수정 찾기 (확정 응답을 늦추지 않음). 실패는 로그만
@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineMemoryEventListener {

  private final RoutineMemoryExtractor routineMemoryExtractor;

  @Async(AsyncConfig.ROUTINE_MEMORY_EXECUTOR)
  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
  public void onExtractionRequested(RoutineMemoryExtractionRequestedEvent event) {
    try {
      routineMemoryExtractor.extract(event.routineId());
    } catch (RuntimeException exception) {
      log.warn("[routine memory] async extraction failed : {}", exception.getClass().getSimpleName());
    }
  }
}
