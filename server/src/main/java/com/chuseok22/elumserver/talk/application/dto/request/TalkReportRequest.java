package com.chuseok22.elumserver.talk.application.dto.request;

/// 신고: targetType 은 POST(글)·COMMENT(댓글), reason 은 PERSONAL_INFO·OFFENSIVE·ADVERTISING·OTHER
public record TalkReportRequest(String targetType, String targetId, String reason) {

}
