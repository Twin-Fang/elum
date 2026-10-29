package com.chuseok22.elumserver.talk.application.dto.response;

/**
 * 앱 밖 공유 페이지에 싣는 글 정보: 분류 이름, 제목(이름 가린 뒤), 한마디 앞부분, 카드 수, 링크 글 여부
 * 글쓴이·댓글은 싣지 않음 (앱 밖으로 나가는 정보 최소화)
 *
 * @param categoryLabel 분류 이름 (링크 글은 분류가 없어 null)
 * @param notePreview   한마디 앞부분 (없으면 null)
 * @param linkOnly      링크로만 보이는 글인가 (이야기 이름·분류 칩을 빼고 그림)
 */
public record TalkSharePage(
  String postId,
  String categoryLabel,
  String title,
  String notePreview,
  int stepCount,
  boolean linkOnly
) {
}
