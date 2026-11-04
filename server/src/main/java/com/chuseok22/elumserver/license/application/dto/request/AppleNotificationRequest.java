package com.chuseok22.elumserver.license.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

@Schema(description = "App Store Server Notifications V2 본문")
public record AppleNotificationRequest(

  @Schema(description = "Apple 이 서명한 알림 JWS")
  String signedPayload
) {

}
