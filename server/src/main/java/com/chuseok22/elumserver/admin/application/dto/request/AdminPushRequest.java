package com.chuseok22.elumserver.admin.application.dto.request;

import java.util.List;

/**
 * 관리자 알림 보내기 요청 (미리 계산·먼저 보내 보기·보내기 공통)
 * targetMode: MEMBERS(고른 회원) 또는 CONDITION(가입일·AI 호출 수). 미리 계산은 제목·본문을 보지 않음
 *
 * @param joinedOnOrBefore   이날(포함)까지 가입한 회원, yyyy-MM-dd
 * @param minimumAiCallCount 지금까지 AI 호출 이 횟수 이상 (0 이면 조건 없음)
 * @param route              누르면 갈 화면: home, plan, myCredit
 * @param testMemberId       먼저 받아 볼 회원 id (먼저 보내 보기만)
 */
public record AdminPushRequest(
  String targetMode,
  List<String> memberIds,
  String joinedOnOrBefore,
  Integer minimumAiCallCount,
  String title,
  String body,
  String route,
  String testMemberId
) {

}
