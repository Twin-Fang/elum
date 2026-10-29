package com.chuseok22.elumserver.talk.core.event;

/// 신고가 저장됨: 커밋 뒤 리스너가 reportId 로 신고 메일을 만든다 (신고자 정보는 싣지 않음)
public record TalkReportedEvent(String reportId) {

}
