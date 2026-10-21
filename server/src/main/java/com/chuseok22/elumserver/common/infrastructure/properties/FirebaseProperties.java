package com.chuseok22.elumserver.common.infrastructure.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * FCM 서비스 계정 키 위치: 클래스패스 리소스 먼저, 없으면 파일 경로
 * 비어 있으면 기본 파일명(firebase-adminsdk.json), 파일이 없으면 푸시 발송을 끈다 (로컬·테스트)
 */
@ConfigurationProperties(prefix = "firebase")
public record FirebaseProperties(String serviceAccountKeyPath) {

  // CI 가 src/main/resources 에 쓰는 파일명 (운영 yml 시크릿에 키가 없어도 찾도록)
  static final String DEFAULT_SERVICE_ACCOUNT_KEY_PATH = "firebase-adminsdk.json";

  public FirebaseProperties {
    if (serviceAccountKeyPath == null || serviceAccountKeyPath.isBlank()) {
      serviceAccountKeyPath = DEFAULT_SERVICE_ACCOUNT_KEY_PATH;
    }
  }
}
