package com.chuseok22.elumserver.license.application.service.store;

import com.chuseok22.elumserver.license.core.StoreVerifyRejectReason;
import lombok.Getter;

/**
 * 스토어 결제 검증 거부 (서명·앱·환경·상품·형식). 컨트롤러 경계에서 사유별 ErrorCode 로 바뀜
 */
@Getter
public class StoreVerifyRejectedException extends RuntimeException {

  private final StoreVerifyRejectReason reason;

  public StoreVerifyRejectedException(StoreVerifyRejectReason reason, String detail) {
    super(reason.name() + (detail == null ? "" : " : " + detail));
    this.reason = reason;
  }
}
