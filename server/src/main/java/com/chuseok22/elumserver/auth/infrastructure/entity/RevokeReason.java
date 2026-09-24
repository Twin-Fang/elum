package com.chuseok22.elumserver.auth.infrastructure.entity;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 리프레시 토큰이 끊긴 이유 (이슈 #360 D1).
 *
 * <p>끊긴 토큰이 다시 오면 서버는 탈취인지 판단해야 한다. <b>회전({@link #ROTATED})으로 끊긴 토큰만</b>
 * 복사본이 돌아다닌다는 신호다 — 정상 앱은 새 토큰을 받는 즉시 옛 것을 버리기 때문이다. 로그아웃처럼
 * 사람이 끊은 토큰은 요청이 겹치거나 로컬 삭제가 실패하면 정상 앱도 한 번 더 보낼 수 있어, 이걸
 * 탈취로 보면 같은 보호자의 다른 휴대폰까지 예고 없이 로그인 화면으로 간다.
 *
 * <p>회원 탈퇴는 토큰 행을 지우므로 사유가 없다.
 */
@Getter
@AllArgsConstructor
public enum RevokeReason {

  ROTATED("갱신으로 교체"),
  LOGOUT("로그아웃"),
  REUSE_DETECTED("재사용 감지"),
  DEVICE_UNLINKED("이룸이 휴대폰 연결 끊김"),
  SUSPENDED("계정 정지"),
  FORCE_LOGOUT("관리자 강제 로그아웃"),
  ;

  private final String label;
}
