package com.chuseok22.elumserver.notification.core.event;

/// 공동 보호자가 초대 코드로 합류함
public record CoGuardianJoinedEvent(String profileId, String joinedMemberId) {

}
