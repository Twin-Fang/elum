package com.chuseok22.elumserver.talk.application.dto.response;

import com.chuseok22.elumserver.talk.infrastructure.entity.TalkComment;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPostStep;
import java.util.List;

/**
 * 관리자 글 상세: 글, 글쓴이, 카드, 모든 상태의 댓글, 신고 목록
 * 닉네임은 없으면 null, 회원 id 는 관리자 회원 상세 링크용 (앱 응답에는 쓰지 않음)
 */
public record TalkAdminPostDetail(
  TalkPost post,
  String authorNickname,
  List<TalkPostStep> steps,
  List<CommentRow> comments,
  List<TalkAdminReportRow> reports
) {

  /** 댓글 한 줄: 댓글, 쓴 사람 닉네임 */
  public record CommentRow(TalkComment comment, String authorNickname) {
  }
}
