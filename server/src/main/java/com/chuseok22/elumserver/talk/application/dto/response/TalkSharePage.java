package com.chuseok22.elumserver.talk.application.dto.response;

/**
 * 앱 밖 공유 페이지에 싣는 글 정보: 분류 이름, 제목, 한마디 앞부분, 카드 수
 * 글쓴이·댓글은 싣지 않음 (앱 밖으로 나가는 정보 최소화)
 *
 * @param notePreview 한마디 앞부분 (없으면 null)
 */
public record TalkSharePage(
  String postId,
  String categoryLabel,
  String title,
  String notePreview,
  int stepCount
) {
}
