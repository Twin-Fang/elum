package com.chuseok22.elumserver.license.application.dto.response;

import com.chuseok22.elumserver.license.application.service.MemberSubscriptionStatus;
import com.chuseok22.elumserver.license.application.service.store.StoreVerification;
import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "스토어 구독 검증 결과")
public record SubscriptionVerifyResponse(

  @Schema(description = "ACTIVE: Pro 이용 중 · INACTIVE: 확인됐지만 Pro 아님(만료·환불·결제 대기) · "
    + "PENDING: 스토어 확인 중, Pro 를 아직 주지 않았으니 잠시 뒤 같은 요청을 다시 보낸다", example = "ACTIVE")
  StoreVerification verification,

  @Schema(description = "반영 후 요금제 상태 (GET /api/member/me 의 subscription 과 같다)")
  MemberSubscriptionStatus subscription
) {

}
