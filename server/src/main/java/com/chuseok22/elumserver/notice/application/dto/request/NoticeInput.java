package com.chuseok22.elumserver.notice.application.dto.request;

/**
 * 관리자가 적은 공지 내용 그대로 (이슈 #370).
 *
 * <p><b>전부 문자열로 받는다.</b> 우선순위 칸에 글자를 넣거나 날짜를 지워도 요청이 바인딩 단계에서
 * 터지지 않고 서비스까지 와서, 어느 칸이 틀렸는지 에러 코드로 돌려줄 수 있게 하려는 것이다.
 * 검증은 {@code NoticeService} 한 곳에서 한다(저장소 규칙상 검증 어노테이션을 달지 않는다).
 *
 * @param startsAt 한국 시각 {@code 2026-09-23T09:00} (브라우저 {@code datetime-local} 값)
 * @param endsAt   비우면 끌 때까지
 */
public record NoticeInput(
  String title,
  String body,
  String buttonLabel,
  String buttonUrl,
  String platform,
  String priority,
  String startsAt,
  String endsAt,
  boolean enabled
) {

}
