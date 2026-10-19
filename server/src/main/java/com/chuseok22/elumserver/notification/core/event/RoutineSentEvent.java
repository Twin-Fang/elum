package com.chuseok22.elumserver.notification.core.event;

/// 일과를 이룸이에게 보냄: actorMemberId 는 보호자 기기가 보냈을 때만 값이 있음 (이룸이 기기면 null)
public record RoutineSentEvent(String routineId, String profileId, String actorMemberId) {

}
