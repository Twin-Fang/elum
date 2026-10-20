package com.chuseok22.elumserver.talk.application.dto.response;

/**
 * 관리자 가리기·되돌리기 결과: 글 id(댓글이면 속한 글), 결과
 * UNCHANGED 는 이미 그 상태이거나 작성자가 지운 글·댓글 (지운 것은 되돌리지 않음)
 */
public record TalkAdminChange(String postId, Result result) {

  public enum Result {
    CHANGED,
    UNCHANGED,
    // 같은 일과로 올린 보이는 글이 따로 있어 되돌리면 한 일과 한 글 규칙에 어긋남
    SOURCE_ALREADY_VISIBLE,
    ;
  }

  public boolean isChanged() {
    return result == Result.CHANGED;
  }
}
