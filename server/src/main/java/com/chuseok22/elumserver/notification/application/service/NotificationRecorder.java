package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.core.NotificationDraft;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;

/**
 * 알림 기록: 받는 사람마다 행 쓰기, 묶음 갱신, 푸시 대상 판정
 * 받는 사람별 독립 트랜잭션 > 실패한 사람은 로그 후 건너뜀 (결과에서 빠짐)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationRecorder {

  private final NotificationRowWriter rowWriter;

  /** 받는 사람 전원에게 기록. 중복 키 위반은 1회만 재시도 (그 사이 다른 요청이 같은 묶음을 만든 경우) */
  public List<RecordedNotification> record(NotificationDraft draft, Collection<String> recipientMemberIds) {
    List<RecordedNotification> recorded = new ArrayList<>();
    if (draft == null || recipientMemberIds == null) {
      log.warn("[notification record] skipped : empty draft or recipients");
      return recorded;
    }
    for (String recipientMemberId : recipientMemberIds) {
      try {
        recorded.add(writeWithOneRetry(draft, recipientMemberId));
      } catch (RuntimeException exception) {
        // 한 명의 실패가 나머지 기록을 막지 않음
        log.warn("[notification record] failed type={} : {}", draft.type(), exception.getClass().getSimpleName());
      }
    }
    return recorded;
  }

  private RecordedNotification writeWithOneRetry(NotificationDraft draft, String recipientMemberId) {
    try {
      return rowWriter.write(draft, recipientMemberId);
    } catch (DataIntegrityViolationException uniqueViolation) {
      // 다시 읽으면 갱신 경로를 탐
      return rowWriter.write(draft, recipientMemberId);
    }
  }
}
