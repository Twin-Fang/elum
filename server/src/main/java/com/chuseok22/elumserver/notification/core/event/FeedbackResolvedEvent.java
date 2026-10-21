package com.chuseok22.elumserver.notification.core.event;

/// 의견이 처리 완료로 바뀜: memberId 는 의견을 보낸 사람 (받는 사람)
public record FeedbackResolvedEvent(String feedbackId, String memberId) {

}
