package com.chuseok22.elumserver.notification.infrastructure.push;

import java.util.Map;

/** 기기 한 대에 보낼 푸시: 토큰, 제목, 본문, 앱이 읽을 data, 같은 묶음끼리 덮어쓸 키, Android 채널(null 이면 앱 기본 채널) */
public record PushMessage(String token, String title, String body, Map<String, String> data, String collapseKey,
  String androidChannelId) {

  /** 보호자 알림: 앱 기본 채널(guardian_updates) */
  public PushMessage(String token, String title, String body, Map<String, String> data, String collapseKey) {
    this(token, title, body, data, collapseKey, null);
  }
}
