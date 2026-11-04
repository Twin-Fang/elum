package com.chuseok22.elumserver.license.application.controller;

import com.chuseok22.elumserver.license.application.dto.request.AppleNotificationRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;

@Tag(
  name = "SubscriptionNotification",
  description = "App Store·Google Play 결제 알림 (#1071). **스토어 서버만 부릅니다.** 인증 헤더가 없고 서명(Apple)·푸시 토큰(Google)이 인증입니다."
)
public interface SubscriptionStoreNotificationControllerDocs {

  @Operation(
    summary = "App Store Server Notifications V2",
    description = """
      App Store Connect > 앱 > App 정보 > App Store 서버 알림(버전 2)에 이 주소를 등록합니다 (운영·Sandbox 같은 주소 가능).

      **처리 로직**
      1. `signedPayload` 의 Apple 서명·번들 ID·앱 ID 를 확인합니다. 틀리면 400, 아무것도 바꾸지 않습니다.
      2. 같은 `notificationUUID` 는 한 번만 처리합니다.
      3. 갱신·해지 예약·만료·환불·결제 유예를 구독 상태에 반영합니다. 앱이 꺼져 있어도 반영됩니다.
      4. 기능이 꺼져 있거나 서버 점검 중이면 503 — Apple 이 나중에 다시 보냅니다.
      5. 테스트 결제 허용이 꺼진 상태의 Sandbox 알림·허용 밖 상품은 200 으로 받고 무시합니다.
      """
  )
  ResponseEntity<String> receiveApple(AppleNotificationRequest request);

  @Operation(
    summary = "Google Play 실시간 개발자 알림 (RTDN, Pub/Sub 푸시)",
    description = """
      Pub/Sub 푸시 구독의 엔드포인트에 `…/api/subscriptions/google/notifications?token=<알림 토큰>` 을 등록합니다.
      토큰은 관리자 설정 `SUBSCRIPTION_GOOGLE_RTDN_PUSH_TOKEN` 과 같아야 합니다(비어 있으면 모두 403).

      **처리 로직**
      1. 토큰이 틀리면 403. 메시지를 읽을 수 없으면 400.
      2. 같은 `messageId` 는 한 번만 처리합니다.
      3. 알림 내용으로 Pro 를 주지 않습니다. Google Play Developer API 로 구독을 **다시 조회해** 반영합니다.
      4. 환불(voidedPurchaseNotification)은 그 구독을 회수합니다.
      5. Google 조회가 실패하거나 기능이 꺼져 있으면 503 — Pub/Sub 이 다시 보냅니다.
      """
  )
  ResponseEntity<String> receiveGoogle(String token, String body);
}
