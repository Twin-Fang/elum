package com.chuseok22.elumserver.common.application.alert;

/**
 * 완성된 알림 문구 > 외부 채널 발송 (구현: DiscordWebhookClient)
 * 실패는 구현이 로그로 남김 (호출자에게 예외 전달 안 함)
 */
public interface IncidentAlertSender {

  void send(String message);
}
