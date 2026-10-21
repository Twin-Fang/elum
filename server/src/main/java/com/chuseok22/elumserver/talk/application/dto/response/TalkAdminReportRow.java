package com.chuseok22.elumserver.talk.application.dto.response;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkReport;

/**
 * 관리자 신고 목록 한 줄: 신고, 신고자 닉네임, 대상 글 제목, 댓글 신고면 댓글 내용
 * 지워져 못 찾은 글·댓글은 null
 */
public record TalkAdminReportRow(
  TalkReport report, String reporterNickname, String postTitle, String commentBody
) {
}
