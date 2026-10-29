package com.chuseok22.elumserver.feedback.core;

/**
 * 관리자 메모 저장 결과 3개: 저장, 지움(빈 값), 길이 초과로 거절(저장 안 함)
 */
public enum FeedbackAdminNoteSaveResult {
  SAVED,
  CLEARED,
  REJECTED_TOO_LONG
}
