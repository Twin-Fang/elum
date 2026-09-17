package com.chuseok22.elumserver.link.core;

/**
 * 같은 계정을 쓰는 두 휴대폰을 구분한다.
 *
 * <p>로그인 계정은 보호자 하나뿐이고 이룸이 휴대폰은 연결 암호로 그 계정에 붙는다.
 * 토큰만 보면 둘이 똑같아서, 구분하지 않으면 이룸이 휴대폰에서 일과 삭제나 회원 탈퇴가
 * 그대로 된다 (이슈 #200).
 */
public enum LinkRole {

  /** 보호자 휴대폰. 지금까지 하던 것 전부. */
  GUARDIAN,

  /** 이룸이(당사자) 휴대폰. 일과를 보고 완료 표시만 한다. */
  ELUMI;

  /** 토큰에 role 클레임이 없던 시절 발급분은 보호자로 본다 — 없다고 막으면 기존 세션이 다 끊긴다. */
  public static LinkRole fromClaim(Object raw) {
    if (raw == null) {
      return GUARDIAN;
    }
    try {
      return valueOf(raw.toString());
    } catch (IllegalArgumentException e) {
      return GUARDIAN;
    }
  }

  public String authority() {
    return "ROLE_" + name();
  }
}
