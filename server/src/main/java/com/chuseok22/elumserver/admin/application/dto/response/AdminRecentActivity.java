package com.chuseok22.elumserver.admin.application.dto.response;

import java.time.LocalDateTime;

/**
 * 대시보드 최근 활동 한 줄 (#1436): 시각, 회원, 무엇 ("카드 3장 체크" 등). 일과 원문·제목은 담지 않음
 */
public record AdminRecentActivity(LocalDateTime occurredAt, String memberId, String displayName, String description) {
}
