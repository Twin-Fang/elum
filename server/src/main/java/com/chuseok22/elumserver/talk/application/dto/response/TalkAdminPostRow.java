package com.chuseok22.elumserver.talk.application.dto.response;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;

/** 관리자 글 목록 한 줄: 글, 글쓴이 닉네임(없으면 null), 미처리 신고 수(글·댓글 합산) */
public record TalkAdminPostRow(TalkPost post, String authorNickname, long unresolvedReportCount) {
}
