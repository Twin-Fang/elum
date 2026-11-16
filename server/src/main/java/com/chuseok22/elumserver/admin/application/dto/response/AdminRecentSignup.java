package com.chuseok22.elumserver.admin.application.dto.response;

import java.time.LocalDateTime;

/**
 * 대시보드 최근 가입 한 줄 (#1436): 가입 시각, 로그인 방법, 사용자 일과 수, 기기 연결 여부, 마지막 활동, 계정 종류 배지
 */
public record AdminRecentSignup(
  String memberId, String displayName, LocalDateTime createdAt, String loginMethodText, long routineCount,
  boolean hasLinkedDevice, LocalDateTime lastActivityAt, String accountKindLabel,
  /// 일반이면 null (배지 없음)
  String accountKindTone
) {
}
