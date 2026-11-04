package com.chuseok22.elumserver.admin.application.dto.response;

import java.time.LocalDateTime;

/**
 * 관리자 Claude 키 카드 한 줄: 우선순위, 별명, 가린 키(끝 4자리), 사용 여부, 상태 (키 값은 담지 않음)
 *
 * @param priority          1부터 (1 = 먼저 씀)
 * @param isLastServed      마지막으로 응답한 키인가 (서버 재시작 후 첫 호출 전이면 모두 false)
 * @param isCoolingDown     실패해 뒤로 미룬 중인가 (cooldownUntil 까지)
 * @param lastFailureLabel  마지막 실패 원인 분류 이름 (없으면 null)
 */
public record AdminClaudeKeyView(
  String id,
  int priority,
  String nickname,
  String maskedKey,
  boolean enabled,
  boolean isLastServed,
  boolean isCoolingDown,
  LocalDateTime lastSuccessAt,
  LocalDateTime lastFailureAt,
  String lastFailureLabel,
  LocalDateTime cooldownUntil,
  boolean isFirst,
  boolean isLast
) {

}
