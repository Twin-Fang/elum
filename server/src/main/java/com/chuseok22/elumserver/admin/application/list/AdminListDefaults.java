package com.chuseok22.elumserver.admin.application.list;

/**
 * 관리자 목록 공통 기본값: 페이지 크기, 기간 필터 기본 일수
 * 서비스마다 선언하지 않고 여기 하나만 참조 (규칙 테스트가 강제)
 */
public final class AdminListDefaults {

  /** 목록 한 쪽 건수 */
  public static final int PAGE_SIZE = 20;

  /** 큰 로그성 목록(AI 모니터링)의 한 쪽 건수 */
  public static final int LOG_PAGE_SIZE = 50;

  /** 기간 필터 기본값 (모니터링·서버 로그): 최근 N일 */
  public static final int DEFAULT_PERIOD_DAYS = 7;

  private AdminListDefaults() {
  }
}
