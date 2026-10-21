package com.chuseok22.elumserver.member.core;

/**
 * 회원 운영 메모 저장 결과 4개: 저장, 지움(빈 값), 길이 초과로 거절, 탈퇴 회원이라 거절 (둘 다 저장 안 함)
 */
public enum MemberAdminMemoSaveResult {
  SAVED,
  CLEARED,
  REJECTED_TOO_LONG,
  REJECTED_WITHDRAWN
}
