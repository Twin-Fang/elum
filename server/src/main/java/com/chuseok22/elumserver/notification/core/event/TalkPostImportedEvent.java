package com.chuseok22.elumserver.notification.core.event;

/// 이야기 글을 보호자가 처음 가져감: authorMemberId 는 글쓴이 (받는 사람), actorMemberId 는 행동한 사람, postTitle 은 푸시 문구용 (저장하지 않음)
public record TalkPostImportedEvent(String postId, String authorMemberId, String actorMemberId, String postTitle) {

}
