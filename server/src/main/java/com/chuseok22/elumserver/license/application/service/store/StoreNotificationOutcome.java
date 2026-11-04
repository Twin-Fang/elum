package com.chuseok22.elumserver.license.application.service.store;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 스토어 알림 처리 결과 > HTTP 응답 코드 (2xx 면 스토어가 다시 보내지 않음)
 */
@Getter
@AllArgsConstructor
public enum StoreNotificationOutcome {

  PROCESSED(200),
  /// 받을 필요 없는 알림 (테스트·다른 앱·허용 밖 상품·테스트 결제 꺼짐·중복)
  IGNORED(200),
  /// 서명·형식 오류
  REJECTED(400),
  /// 알림 토큰 불일치 (Google)
  FORBIDDEN(403),
  /// 기능 꺼짐·스토어 확인 실패 > 스토어가 다시 보내게
  RETRY_LATER(503),
  ;

  private final int httpStatus;
}
