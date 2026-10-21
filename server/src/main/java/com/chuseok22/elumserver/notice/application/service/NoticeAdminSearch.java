package com.chuseok22.elumserver.notice.application.service;

import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.core.NoticeStatus;
import java.time.LocalDateTime;

/**
 * 관리자 공지 검색 조건 4개: 제목·본문 검색, 상태, 대상 플랫폼, 게시 기간과 겹치는 날짜 범위(시작 포함·끝 미포함)
 * 검색 패턴은 호출부가 LIKE 이스케이프해 넘김 (ESCAPE '\'). null 인 조건은 빠짐
 */
public record NoticeAdminSearch(
  String likePattern,
  NoticeStatus status,
  NoticePlatform platform,
  LocalDateTime periodFrom,
  LocalDateTime periodToExclusive
) {

  /// 조건 없음 (전체)
  public static NoticeAdminSearch none() {
    return new NoticeAdminSearch(null, null, null, null, null);
  }
}
