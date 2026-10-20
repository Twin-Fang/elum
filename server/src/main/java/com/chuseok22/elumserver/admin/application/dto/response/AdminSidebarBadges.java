package com.chuseok22.elumserver.admin.application.dto.response;

/** 사이드바 배지 3개: 새 의견 수, 검토 대기 일과 수, AI 이상 제공자 수 */
public record AdminSidebarBadges(long newFeedbackCount, long pendingReviewRoutineCount, long aiAlertCount) {
}
