package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.core.NotificationType;
import java.time.LocalDateTime;
import java.util.Collection;

/**
 * 관리자 알림 검색 조건: 마지막 발생 기간[from, to), 받는 보호자, 종류, 읽음 여부
 *
 * @param memberIds null 이면 회원 조건 없음, 비어 있으면 결과 0건
 * @param isRead    true 읽음, false 안 읽음, null 전체
 */
public record NotificationAdminSearch(
  LocalDateTime from,
  LocalDateTime to,
  Collection<String> memberIds,
  NotificationType type,
  Boolean isRead
) {

}
