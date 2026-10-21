package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.admin.application.list.AdminNotificationList;
import com.chuseok22.elumserver.notification.application.dto.response.NotificationAdminView;

/**
 * 알림 기록 목록의 한 줄: 알림 + 받는 보호자 표시 이름 + 종류 표시 이름
 *
 * @param memberDisplayName 없는 회원(완전 삭제)이면 null
 */
public record AdminNotificationRow(NotificationAdminView notification, String memberDisplayName, String typeLabel) {

  public static AdminNotificationRow of(NotificationAdminView notification, String memberDisplayName) {
    return new AdminNotificationRow(notification, memberDisplayName,
      AdminNotificationList.typeLabelOf(notification.type()));
  }
}
