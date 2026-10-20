package com.chuseok22.elumserver.notification.infrastructure.push;

import java.util.Map;

/** 기기 한 대에 보낼 푸시: 토큰, 제목, 본문, 앱이 읽을 data, 같은 묶음끼리 덮어쓸 키 */
public record PushMessage(String token, String title, String body, Map<String, String> data, String collapseKey) {
}
