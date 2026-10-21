package com.chuseok22.elumserver.notification.infrastructure.push;

/** 푸시 한 건 발송: 실패는 예외 대신 결과로 돌려줌 */
public interface PushSender {

  PushResult send(PushMessage message);
}
