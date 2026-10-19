package com.chuseok22.elumserver.notification.infrastructure.push;

/** 발송 결과: 성공, 무효 토큰(기기 삭제 대상), 그 밖의 실패 */
public enum PushResult {
  SENT,
  INVALID_TOKEN,
  FAILED
}
