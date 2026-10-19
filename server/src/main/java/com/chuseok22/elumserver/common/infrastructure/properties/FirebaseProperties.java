package com.chuseok22.elumserver.common.infrastructure.properties;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * FCM 서비스 계정 키 위치: 클래스패스 리소스 먼저, 없으면 파일 경로
 * 비어 있으면 푸시 발송을 끈다 (로컬·테스트)
 */
@ConfigurationProperties(prefix = "firebase")
public record FirebaseProperties(String serviceAccountKeyPath) {
}
