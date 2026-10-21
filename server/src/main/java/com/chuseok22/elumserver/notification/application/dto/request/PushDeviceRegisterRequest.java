package com.chuseok22.elumserver.notification.application.dto.request;

import com.chuseok22.elumserver.notification.core.PushPlatform;
import io.swagger.v3.oas.annotations.media.Schema;

/// 검증 어노테이션을 쓰지 않는다. 토큰 검사는 PushDeviceService 가 CustomException 으로 던진다.
@Schema(description = "푸시 기기 등록 요청")
public record PushDeviceRegisterRequest(
  @Schema(description = "푸시 토큰. 필수, 공백만이면 거절, 최대 2048자")
  String token,
  @Schema(description = "기기 운영체제 (IOS, ANDROID)", example = "IOS")
  PushPlatform platform
) {
}
