package com.chuseok22.elumserver.talk.application.dto.request;

/// 차단: 글(postId)과 댓글(commentId) 중 정확히 하나만 보내면 그 글쓴이를 차단
public record TalkBlockRequest(String postId, String commentId) {

}
