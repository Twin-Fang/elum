package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.core.NotificationDraft;
import com.chuseok22.elumserver.notification.core.NotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.Notification;
import com.chuseok22.elumserver.notification.infrastructure.repository.NotificationRepository;
import java.util.Arrays;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * 받는 사람 한 명의 알림 행 쓰기: 조회 > 새 줄 또는 묶음 갱신 > 즉시 flush
 * 별도 빈인 이유: 같은 클래스 안 호출이면 REQUIRES_NEW 프록시가 적용되지 않음
 */
@Service
@RequiredArgsConstructor
class NotificationRowWriter {

  // 일과 id 목록 구분자

  private final NotificationRepository notificationRepository;

  /** 받는 사람별 독립 커밋 (한 명 실패가 다른 사람에 번지지 않게). 중복 키 위반은 예외로 올려 호출부가 재시도 */
  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public RecordedNotification write(NotificationDraft draft, String recipientMemberId) {
    Optional<Notification> existing =
      notificationRepository.findForUpdateByRecipientMemberIdAndGroupKey(recipientMemberId, draft.groupKey());
    if (existing.isEmpty()) {
      return insert(draft, recipientMemberId);
    }
    return updateExisting(existing.get(), draft);
  }

  private RecordedNotification insert(NotificationDraft draft, String recipientMemberId) {
    Notification created = new Notification();
    created.setRecipientMemberId(recipientMemberId);
    created.setProfileId(draft.profileId());
    created.setType(draft.type());
    created.setTargetId(draft.targetId());
    created.setGroupKey(draft.groupKey());
    created.setSubjectIds(draft.subjectId());
    created.setCount(1);
    created.setLastOccurredAt(draft.occurredAt());
    // flush 로 중복 키 위반을 이 트랜잭션 안에서 드러냄
    Notification saved = notificationRepository.saveAndFlush(created);
    return new RecordedNotification(saved.getId(), recipientMemberId, saved.getCount(), true);
  }

  private RecordedNotification updateExisting(Notification row, NotificationDraft draft) {
    // 묶음 없는 종류: 이미 있으면 아무것도 안 함
    if (draft.type() != NotificationType.ROUTINE_COMPLETED || draft.subjectId() == null) {
      return new RecordedNotification(row.getId(), row.getRecipientMemberId(), row.getCount(), false);
    }
    // 같은 일과를 다시 완료: 횟수 유지, 푸시 안 함
    if (hasSubject(row.getSubjectIds(), draft.subjectId())) {
      return new RecordedNotification(row.getId(), row.getRecipientMemberId(), row.getCount(), false);
    }
    // 다른 일과 완료: 횟수 +1, 일과 id 추가, 다시 안 읽음 상태로
    String mergedSubjectIds = row.getSubjectIds() == null || row.getSubjectIds().isBlank()
      ? draft.subjectId()
      : row.getSubjectIds() + Notification.SUBJECT_ID_DELIMITER + draft.subjectId();
    row.setSubjectIds(mergedSubjectIds);
    row.setCount(row.getCount() + 1);
    row.setLastOccurredAt(draft.occurredAt());
    row.setReadAt(null);
    Notification saved = notificationRepository.saveAndFlush(row);
    return new RecordedNotification(saved.getId(), row.getRecipientMemberId(), saved.getCount(), true);
  }

  private boolean hasSubject(String subjectIds, String subjectId) {
    return subjectIds != null && Arrays.asList(subjectIds.split(Notification.SUBJECT_ID_DELIMITER)).contains(subjectId);
  }
}
