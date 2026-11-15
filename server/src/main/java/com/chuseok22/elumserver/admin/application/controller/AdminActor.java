package com.chuseok22.elumserver.admin.application.controller;

import java.security.Principal;

/**
 * 관리자 화면 요청의 행위자 이름 (설정 변경 이력·원장 actor·감사 기록에 남김). 로그인 정보가 없으면 null
 */
final class AdminActor {

  private AdminActor() {
  }

  static String nameOf(Principal principal) {
    return principal == null ? null : principal.getName();
  }
}
