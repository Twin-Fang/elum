package com.chuseok22.elumserver.notification.core.event;

import java.time.LocalDate;

/// 일과가 새로 완료됨: actorMemberId 는 보호자 기기가 완료했을 때만 값이 있음 (이룸이 기기면 null)
public record RoutineCompletedEvent(String routineId, String profileId, LocalDate routineDate, String actorMemberId) {

}
