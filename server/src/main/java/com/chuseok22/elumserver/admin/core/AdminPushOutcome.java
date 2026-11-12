package com.chuseok22.elumserver.admin.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 관리자 알림 보내기 결과 8개 (#1273): 보낼 수 있음, 보냄, 거절 사유 6개
 * 거절은 화면에 문구 + 오류 코드(E-PUSH-xxx)로 보임
 */
@Getter
@AllArgsConstructor
public enum AdminPushOutcome {

  READY(true, "보낼 수 있어요", null),
  SENT(true, "보냈어요", null),
  NO_RECIPIENTS(false, "받을 회원이 없어요", "E-PUSH-001"),
  TOO_MANY_RECIPIENTS(false, "한 번에 1,000명까지 보낼 수 있어요. 조건을 좁혀 주세요", "E-PUSH-002"),
  QUIET_HOURS(false, "밤 9시부터 아침 8시까지는 보낼 수 없어요. 나에게 먼저 보내 보기는 돼요", "E-PUSH-003"),
  INVALID_TARGET(false, "받는 사람 조건을 확인해 주세요 (가입일, AI 호출 수)", "E-PUSH-004"),
  INVALID_MESSAGE(false, "제목(50자)·본문(300자)·누르면 갈 화면을 확인해 주세요", "E-PUSH-005"),
  TEST_MEMBER_INVALID(false, "먼저 받아 볼 회원을 고르세요 (활성 회원만)", "E-PUSH-006"),
  ;

  private final boolean isAccepted;
  private final String message;
  private final String errorCode;
}
