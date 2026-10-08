package com.chuseok22.elumserver.admin.application.dto.request;

import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;

/**
 * 약관 편집 화면의 입력값.
 *
 * <p>검증에 걸렸을 때 <b>관리자가 입력한 값을 그대로 다시 그리기</b> 위해 둔다.
 * 오류가 나면 편집 화면으로 리다이렉트해 DB 값을 다시 읽으면 고치던 전문이 통째로 사라지기 때문이다.
 */
public record ConsentEditForm(
  String label,
  String summary,
  String body,
  boolean bumpVersion,
  String newVersion,
  String reason
) {

  /** 처음 열 때는 지금 문서 값으로 채운다. 새 버전 칸에는 오늘 날짜를 미리 넣는다. */
  public static ConsentEditForm of(ConsentDocument document, String today) {
    return new ConsentEditForm(
      document.getLabel(), document.getSummary(), document.getBody(), false, today, "");
  }
}
