package com.chuseok22.elumserver.admin.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 관리자 기록 동작 12개 (#653): 표시 이름, 대상 종류, 동작 뒤 대상이 사라지는지(링크를 걸지 않음)
 * 크레딧 조정·예약 반환은 원장(actor·사유)에, 시스템 설정은 설정 변경 이력에 남아 여기서 기록하지 않음
 */
@Getter
@AllArgsConstructor
public enum AdminAuditAction {

  MEMBER_SUSPENDED("계정 정지", AdminAuditTargetType.MEMBER, false),
  MEMBER_UNSUSPENDED("정지 해제", AdminAuditTargetType.MEMBER, false),
  MEMBER_FORCE_LOGGED_OUT("강제 로그아웃", AdminAuditTargetType.MEMBER, false),
  PRO_GRANTED("Pro 발급", AdminAuditTargetType.MEMBER, false),
  PRO_REVOKED("Pro 회수", AdminAuditTargetType.MEMBER, false),
  DEVICE_UNLINKED("이룸이 기기 연결 해제", AdminAuditTargetType.MEMBER, false),
  MEMBER_MEMO_SAVED("회원 메모 저장", AdminAuditTargetType.MEMBER, false),
  WITHDRAWN_MEMBER_PURGED("탈퇴 계정 즉시 삭제", AdminAuditTargetType.MEMBER, true),
  PROMPT_UPDATED("프롬프트 저장", AdminAuditTargetType.PROMPT, false),
  FEEDBACK_NOTE_SAVED("의견 메모 저장", AdminAuditTargetType.FEEDBACK, false),
  FEEDBACK_DELETED("의견 삭제", AdminAuditTargetType.FEEDBACK, true),
  LOG_FILE_DELETED("로그 파일 삭제", AdminAuditTargetType.LOG_FILE, true),
  ;

  private final String label;
  private final AdminAuditTargetType targetType;
  /// 동작 뒤 대상 화면이 없어짐 (삭제류): 목록에서 대상 링크를 걸지 않음
  private final boolean isTargetRemoved;
}
