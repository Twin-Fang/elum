package com.chuseok22.elumserver.admin.application.dto.response;

/**
 * 대시보드 지금·오늘 숫자: 지금 접속 중(최근 5분 활동), 오늘·어제 방문, 오늘 신규 가입
 */
public record AdminDashboardActivity(long onlineCount, long todayVisitCount, long yesterdayVisitCount, long todayJoinedCount) {
}
