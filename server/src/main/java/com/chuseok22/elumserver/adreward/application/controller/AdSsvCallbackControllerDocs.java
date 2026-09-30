package com.chuseok22.elumserver.adreward.application.controller;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;

@Tag(
  name = "AdSsv",
  description = "Google AdMob 보상형 광고 서버 콜백 (#463). **Google 서버만 부릅니다.** 인증 헤더가 없고, 서명이 인증입니다."
)
public interface AdSsvCallbackControllerDocs {

  @Operation(
    summary = "Google 보상형 광고 콜백(SSV)",
    description = """
      AdMob 콘솔의 보상형 광고 단위 → 서버 측 인증(SSV) 콜백 URL에 이 주소를 등록합니다.
      Google 이 광고 시청이 끝날 때마다 `ad_unit` · `custom_data`(우리 세션 nonce) · `transaction_id` · `signature` ·
      `key_id` 등을 쿼리로 붙여 GET 으로 부릅니다.

      **처리 로직**
      1. `signature`·`key_id`(항상 마지막 두 파라미터)로 **원문 쿼리를 ECDSA 서명 검증**합니다. 틀리면 400, 아무것도 주지 않습니다.
      2. Google 공개키를 받지 못해 확인할 수 없으면 503 — 주지 않고, Google 이 다시 보내게 합니다.
      3. 서명이 맞으면 세션을 잠그고 **한 번만** 크레딧을 줍니다. 이미 준 시청·알 수 없는 세션·규칙에 걸린 경우도
         **200** 으로 답합니다(Google 이 의미 없이 다시 보내지 않게). 사유는 세션에 남습니다.
      4. 지급 중 DB 오류가 나면 500 — 세션은 그대로 남아 Google 재시도 때 다시 처리됩니다.

      지급량은 서버 설정이 정합니다. Google 이 보낸 `reward_amount` 는 쓰지 않습니다.
      """
  )
  ResponseEntity<String> receive(HttpServletRequest request);
}
