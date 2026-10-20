package com.chuseok22.elumserver.talk.infrastructure.mail;

/**
 * 신고 메일 내용: 신고 id, 대상 종류·사유 이름, 글 제목, 내용 일부(최대 200자), 관리자 링크
 * 신고자 정보는 담지 않음
 */
public record TalkReportNotice(
  String reportId, String targetType, String reasonLabel, String postTitle, String excerpt, String adminUrl) {

  // 메일에 싣는 내용 일부 최대 글자 수
  public static final int MAX_EXCERPT_CHARACTERS = 200;

  public TalkReportNotice {
    if (excerpt != null && excerpt.codePointCount(0, excerpt.length()) > MAX_EXCERPT_CHARACTERS) {
      excerpt = excerpt.substring(0, excerpt.offsetByCodePoints(0, MAX_EXCERPT_CHARACTERS));
    }
  }
}
