package com.chuseok22.elumserver.notification.infrastructure.push;

import com.chuseok22.elumserver.common.infrastructure.properties.FirebaseProperties;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.FirebaseMessaging;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.ClassPathResource;

/**
 * 푸시 발송기 선택: 서비스 계정 키가 있으면 FCM, 없거나 초기화 실패면 빈 발송기
 * 키 위치: 클래스패스 리소스 > 파일 경로 (어느 쪽이든 앱 기동은 막지 않음)
 */
@Slf4j
@Configuration
public class PushSenderConfig {

  @Bean
  public PushSender pushSender(FirebaseProperties firebaseProperties) {
    return createPushSender(firebaseProperties.serviceAccountKeyPath());
  }

  PushSender createPushSender(String serviceAccountKeyPath) {
    if (serviceAccountKeyPath == null || serviceAccountKeyPath.isBlank()) {
      return disabledSender("no service account key");
    }
    try (InputStream keyStream = openKeyStream(serviceAccountKeyPath.trim())) {
      if (keyStream == null) {
        return disabledSender("no service account key");
      }
      FirebaseOptions options = FirebaseOptions.builder()
        .setCredentials(GoogleCredentials.fromStream(keyStream))
        // 기본 전송기는 FCM 의 gzip 응답을 두 번 풀어 오류 코드를 못 읽음 (java.net 전송기는 정상)
        .setHttpTransport(new NetHttpTransport())
        .build();
      // 같은 이름 앱이 이미 있으면 재사용 (컨텍스트 재시작·테스트)
      FirebaseApp firebaseApp = FirebaseApp.getApps().isEmpty()
        ? FirebaseApp.initializeApp(options)
        : FirebaseApp.getInstance();
      log.info("[notification push] enabled : fcm");
      return new FcmPushSender(FirebaseMessaging.getInstance(firebaseApp));
    } catch (IOException | RuntimeException exception) {
      // 잘못된 JSON 등: 기동 실패 대신 푸시만 끔
      return disabledSender("service account key unusable (" + exception.getClass().getSimpleName() + ")");
    }
  }

  // 클래스패스 리소스 먼저, 없으면 파일. 둘 다 없으면 null
  private InputStream openKeyStream(String keyPath) throws IOException {
    ClassPathResource classpathResource = new ClassPathResource(keyPath);
    if (classpathResource.exists()) {
      return classpathResource.getInputStream();
    }
    Path keyFile = Path.of(keyPath);
    return Files.isReadable(keyFile) ? Files.newInputStream(keyFile) : null;
  }

  private PushSender disabledSender(String reason) {
    log.warn("[notification push] disabled : {}", reason);
    return new NoOpPushSender();
  }
}
