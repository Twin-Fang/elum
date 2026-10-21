package com.chuseok22.elumserver.feedback.application.service;

import com.chuseok22.elumserver.feedback.core.FeedbackStatus;
import java.time.LocalDateTime;

/**
 * 관리자 의견 검색 조건 6개: 본문·회원 id 검색, 처리 상태, 보낸 기간(시작 포함·끝 미포함), 앱 버전, OS
 * 문자열 패턴은 호출부가 LIKE 이스케이프해 넘김 (ESCAPE '\'). null 인 조건은 쿼리에서 빠짐
 */
public record FeedbackAdminSearch(
  String likePattern,
  FeedbackStatus status,
  LocalDateTime createdFrom,
  LocalDateTime createdToExclusive,
  String appVersionPattern,
  String osPattern
) {

  /// 조건 없음 (전체)
  public static FeedbackAdminSearch none() {
    return new FeedbackAdminSearch(null, null, null, null, null, null);
  }
}
