package com.chuseok22.elumserver.feedback.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;

/// 검증 어노테이션을 쓰지 않는다. 길이·공백 검사는 FeedbackService 가 CustomException 으로 던진다.
@Schema(description = "의견 보내기 요청")
public record FeedbackRequest(
  @Schema(description = "의견 글. 필수, 공백만이면 거절, 최대 2000자", example = "카드를 만들 때 느려요")
  String message,
  @Schema(description = "앱 상태 기록. 선택, 최대 64KB(UTF-8). 보내지 않으면 null")
  String appLog,
  @Schema(description = "앱 버전. 최대 32자, 넘으면 잘라 저장", example = "1.0.40")
  String appVersion,
  @Schema(description = "OS 이름과 버전. 최대 64자, 넘으면 잘라 저장", example = "iOS 18.1")
  String os
) {
}
