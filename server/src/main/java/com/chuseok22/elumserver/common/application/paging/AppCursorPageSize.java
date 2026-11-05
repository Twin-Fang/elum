package com.chuseok22.elumserver.common.application.paging;

/**
 * 앱 커서 목록 한 쪽 크기 보정: 비면 20, 1~50 로 자름
 * 쓰는 목록 5개: 알림, 공지 기록, 이야기 피드·내 글, 댓글 (크레딧 내역은 기본 30이라 따로)
 */
public final class AppCursorPageSize {

  public static final int DEFAULT_PAGE_SIZE = 20;
  public static final int MAX_PAGE_SIZE = 50;

  private AppCursorPageSize() {
  }

  /// 요청 크기(null 이면 기본) > 1~MAX_PAGE_SIZE
  public static int resolve(Integer requestedSize) {
    return requestedSize == null ? DEFAULT_PAGE_SIZE : Math.clamp(requestedSize, 1, MAX_PAGE_SIZE);
  }
}
