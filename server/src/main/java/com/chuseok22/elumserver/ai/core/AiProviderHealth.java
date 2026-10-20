package com.chuseok22.elumserver.ai.core;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 제공자 상태 판정 결과 5개: 크레딧 소진 의심, 키 오류, 오류 늘어남, 호출 없음, 정상
 * isAlert: 관리자에게 확인할 일로 올릴 상태
 */
@Getter
@AllArgsConstructor
public enum AiProviderHealth {

  CREDIT_EXHAUSTED("크레딧 소진 의심", true),
  KEY_INVALID("키 오류", true),
  DEGRADED("오류 늘어남", true),
  IDLE("호출 없음", false),
  HEALTHY("정상", false),
  ;

  private final String label;
  private final boolean isAlert;
}
