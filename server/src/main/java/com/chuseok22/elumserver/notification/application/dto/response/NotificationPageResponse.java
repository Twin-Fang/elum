package com.chuseok22.elumserver.notification.application.dto.response;

import java.util.List;

/// 알림 목록 한 쪽. nextCursor 가 null 이면 마지막 쪽
public record NotificationPageResponse(List<NotificationItemResponse> items, String nextCursor) {

}
