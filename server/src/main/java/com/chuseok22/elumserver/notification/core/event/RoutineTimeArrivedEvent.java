package com.chuseok22.elumserver.notification.core.event;

/// 반복 일과의 정한 시각이 됨 (#1080): routineId 는 이룸이가 열 오늘 일과 (원본이 아님), scheduleId 는 발송 결과 로그용
public record RoutineTimeArrivedEvent(String routineId, String profileId, String scheduleId) {

}
