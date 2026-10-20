package com.chuseok22.elumserver.notification.infrastructure.push;

import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.Aps;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Notification;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;

/**
 * FCM 발송기: 알림 메시지 1건 전송, 오류 코드 > 결과 변환
 * 같은 묶음은 Android tag/collapseKey, iOS apns-collapse-id 로 알림창에서 한 줄로 덮어씀
 */
@Slf4j
public class FcmPushSender implements PushSender {

  // apns-collapse-id 최대 길이 (바이트)
  private static final int APNS_COLLAPSE_ID_MAX_BYTES = 64;
  private static final String APNS_COLLAPSE_ID_HEADER = "apns-collapse-id";

  private final FirebaseMessaging firebaseMessaging;

  public FcmPushSender(FirebaseMessaging firebaseMessaging) {
    this.firebaseMessaging = firebaseMessaging;
  }

  @Override
  public PushResult send(PushMessage pushMessage) {
    try {
      firebaseMessaging.send(toFcmMessage(pushMessage));
      return PushResult.SENT;
    } catch (FirebaseMessagingException exception) {
      MessagingErrorCode errorCode = exception.getMessagingErrorCode();
      // 토큰이 무효: UNREGISTERED(앱 삭제·만료), INVALID_ARGUMENT(형식 오류)
      if (errorCode == MessagingErrorCode.UNREGISTERED || errorCode == MessagingErrorCode.INVALID_ARGUMENT) {
        log.info("[notification push] invalid token reported : {}", errorCode);
        return PushResult.INVALID_TOKEN;
      }
      if (errorCode == null && exception.getHttpResponse() != null) {
        log.warn("[notification push] failed : http {}", exception.getHttpResponse().getStatusCode());
        return PushResult.FAILED;
      }
      log.warn("[notification push] failed : {}", errorCode);
      return PushResult.FAILED;
    } catch (RuntimeException exception) {
      log.warn("[notification push] failed : {}", exception.getClass().getSimpleName());
      log.debug("[notification push] failure detail", exception);
      return PushResult.FAILED;
    }
  }

  // 발송 없이 메시지만 조립 (테스트에서 직접 호출)
  Message toFcmMessage(PushMessage pushMessage) {
    // 길이 제한(APNs 64바이트)을 모든 플랫폼에 같은 키로 맞춤
    String collapseKey = toStableShortKey(pushMessage.collapseKey());
    return Message.builder()
      .setToken(pushMessage.token())
      .setNotification(Notification.builder().setTitle(pushMessage.title()).setBody(pushMessage.body()).build())
      .putAllData(nonBlankEntries(pushMessage.data()))
      .setAndroidConfig(AndroidConfig.builder()
        .setCollapseKey(collapseKey)
        .setNotification(AndroidNotification.builder().setTag(collapseKey).build())
        .build())
      .setApnsConfig(ApnsConfig.builder()
        .putHeader(APNS_COLLAPSE_ID_HEADER, collapseKey)
        // SDK 가 aps 를 필수로 요구: 보이는 알림은 Notification 페이로드에서 채워짐
        .setAps(Aps.builder().setSound("default").build())
        .build())
      .build();
  }

  // FCM data 는 null 값을 거부하므로 null·빈 값 항목은 뺌
  static Map<String, String> nonBlankEntries(Map<String, String> data) {
    Map<String, String> filtered = new HashMap<>();
    data.forEach((key, value) -> {
      if (key != null && value != null && !value.isBlank()) {
        filtered.put(key, value);
      }
    });
    return filtered;
  }

  // 64바이트 이하는 그대로, 넘으면 SHA-256 hex(64자)
  static String toStableShortKey(String key) {
    if (key.getBytes(StandardCharsets.UTF_8).length <= APNS_COLLAPSE_ID_MAX_BYTES) {
      return key;
    }
    try {
      byte[] digest = MessageDigest.getInstance("SHA-256").digest(key.getBytes(StandardCharsets.UTF_8));
      return HexFormat.of().formatHex(digest);
    } catch (NoSuchAlgorithmException exception) {
      throw new IllegalStateException(exception);
    }
  }
}
