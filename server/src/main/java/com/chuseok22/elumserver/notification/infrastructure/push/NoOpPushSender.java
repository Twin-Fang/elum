package com.chuseok22.elumserver.notification.infrastructure.push;

/** 키가 없을 때의 빈 발송기: 아무것도 보내지 않음 */
public class NoOpPushSender implements PushSender {

  @Override
  public PushResult send(PushMessage message) {
    return PushResult.FAILED;
  }
}
