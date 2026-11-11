package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/// AI 메모리 수치: 자동 적용 횟수 (설정 2~10, 범위 밖이면 기본 3), 보호자당 규칙 수 상한, 일과 만들 때 넣는 규칙 수 상한
@Component
@RequiredArgsConstructor
public class RoutineMemoryPolicy {

  static final int MIN_AUTO_APPLY_COUNT = 2;
  static final int MAX_AUTO_APPLY_COUNT = 10;
  static final int DEFAULT_AUTO_APPLY_COUNT = 3;
  /// (이룸이, 보호자) 한 쌍이 가질 수 있는 규칙 수 (넘으면 새 관찰 규칙은 만들지 않음)
  static final int MAX_RULES_PER_OWNER = 100;
  /// 직접 적은 규칙 최대 수
  static final int MAX_MANUAL_RULES_PER_OWNER = 20;
  /// 일과 만들 때 넣는 ACTIVE 규칙 최대 수 (프롬프트 토큰 제한)
  static final int MAX_APPLIED_RULES = 10;
  /// AI 에 보내는 기존 규칙 최대 수
  static final int MAX_RULES_SENT_TO_AI = 50;
  /// 규칙마다 보여 주는 근거 수, 수정 기록 수
  static final int MAX_EVIDENCES_SHOWN = 5;
  static final int MAX_EDITS_SHOWN = 20;

  private final SystemConfigService systemConfigService;

  public int autoApplyCount() {
    int configured = systemConfigService.getInt(ConfigKey.ROUTINE_MEMORY_AUTO_APPLY_COUNT);
    boolean isInRange = configured >= MIN_AUTO_APPLY_COUNT && configured <= MAX_AUTO_APPLY_COUNT;
    return isInRange ? configured : DEFAULT_AUTO_APPLY_COUNT;
  }
}
