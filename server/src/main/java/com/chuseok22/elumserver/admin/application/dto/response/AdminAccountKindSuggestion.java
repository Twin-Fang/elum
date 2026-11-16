package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.member.core.MemberAccountKind;
import java.time.LocalDateTime;

/**
 * 분류 제안 한 줄 (#1436): 회원, 가입 시각, 제안 종류, 이유 (자동 분류 아님, 관리자가 버튼으로 결정)
 */
public record AdminAccountKindSuggestion(
  String memberId, String displayName, LocalDateTime createdAt, MemberAccountKind suggestedKind, String reason
) {
}
