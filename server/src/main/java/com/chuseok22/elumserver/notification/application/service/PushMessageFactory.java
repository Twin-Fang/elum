package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.notification.core.NotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.Notification;
import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import com.chuseok22.elumserver.notification.infrastructure.push.PushMessage;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.text.MessageFormat;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ConcurrentHashMap;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 푸시 메시지 조립: 종류 + 기기 언어 > 제목·본문, 알림 행 > data·묶음 키
 * 문구는 i18n/push-messages_{언어}.properties (UTF-8), 없는 언어는 en. 입력 원문은 어디에도 넣지 않음
 */
@Slf4j
@Component
public class PushMessageFactory {

  private static final String BUNDLE_RESOURCE = "i18n/push-messages_%s.properties";
  private static final String TITLE_KEY = "push.title";
  private static final String ROUTINE_COMPLETED_ONE_KEY = "push.routine_completed.one";
  private static final String ROUTINE_COMPLETED_MANY_KEY = "push.routine_completed.many";

  // 이룸이 기기 알림: 알림 행 없이 보내므로 NotificationType 밖의 종류 (앱 push_message_router 와 같은 값)
  public static final String ELUMI_ROUTINE_ARRIVED_TYPE = "ELUMI_ROUTINE_ARRIVED";
  private static final String ELUMI_ROUTINE_ARRIVED_KEY = "push.elumi_routine_arrived";
  // 같은 일과를 다시 보내면 알림창에서 한 줄로 덮어씀
  private static final String ELUMI_ROUTINE_COLLAPSE_PREFIX = "elumi-routine-";
  // 앱이 만드는 이룸이 알림 채널 id (앱 push_message_router 와 같은 값)
  static final String ELUMI_ROUTINES_CHANNEL_ID = "elumi_routines";

  // 언어별 문구 캐시
  private final Map<AppLocale, Properties> bundleByLocale = new ConcurrentHashMap<>();

  /** 알림 행 + 기록 결과 + 받는 기기 > 푸시 메시지 */
  public PushMessage create(Notification notification, RecordedNotification recorded, PushDevice device) {
    return create(notification, recorded, device, null);
  }

  /** 문구에 글 제목이 들어가는 종류(이야기)는 subjectTitle 을 넘김 (저장하지 않는 값) */
  public PushMessage create(Notification notification, RecordedNotification recorded, PushDevice device,
    String subjectTitle) {
    NotificationType type = notification.getType();
    AppLocale locale = device.getLocale() == null ? AppLocale.EN : device.getLocale();
    String title = text(locale, TITLE_KEY);
    String body = buildBody(type, recorded.count(), locale, subjectTitle);
    return new PushMessage(device.getToken(), title, body, buildData(notification, type), notification.getGroupKey());
  }

  private String buildBody(NotificationType type, int count, AppLocale locale, String subjectTitle) {
    return switch (type) {
      case ROUTINE_COMPLETED -> count >= 2
        ? MessageFormat.format(text(locale, ROUTINE_COMPLETED_MANY_KEY), count)
        : text(locale, ROUTINE_COMPLETED_ONE_KEY);
      case ROUTINE_SENT_BY_CO_GUARDIAN -> text(locale, "push.routine_sent");
      case CO_GUARDIAN_JOINED -> text(locale, "push.co_guardian_joined");
      case CREDIT_REFILLED -> text(locale, "push.credit_refilled");
      case FEEDBACK_RESOLVED -> text(locale, "push.feedback_resolved");
      // {0} 글 제목, {1} 댓글 수 또는 가져간 보호자 수
      case TALK_POST_COMMENTED -> MessageFormat.format(text(locale, "push.talk_post_commented"),
        subjectTitle == null ? "" : subjectTitle, count);
      case TALK_POST_IMPORTED -> MessageFormat.format(text(locale, "push.talk_post_imported"),
        subjectTitle == null ? "" : subjectTitle, count);
    };
  }

  /** 이룸이 기기 일과 도착: 일과 제목은 넣지 않음 (잠금 화면 노출) */
  public PushMessage createElumiRoutineArrived(PushDevice device, String profileId, String routineId) {
    AppLocale locale = device.getLocale() == null ? AppLocale.EN : device.getLocale();
    Map<String, String> pushData = new HashMap<>();
    pushData.put("type", ELUMI_ROUTINE_ARRIVED_TYPE);
    putIfPresent(pushData, "profileId", profileId);
    putIfPresent(pushData, "routineId", routineId);
    return new PushMessage(device.getToken(), text(locale, TITLE_KEY), text(locale, ELUMI_ROUTINE_ARRIVED_KEY),
      pushData, ELUMI_ROUTINE_COLLAPSE_PREFIX + routineId, ELUMI_ROUTINES_CHANNEL_ID);
  }

  // data: 앱이 눌렀을 때 화면을 정하는 id 만 (없는 값은 키째 뺌: FCM 이 null 값을 거부)
  private Map<String, String> buildData(Notification notification, NotificationType type) {
    Map<String, String> pushData = new HashMap<>();
    pushData.put("type", type.name());
    putIfPresent(pushData, "notificationId", notification.getId());
    putIfPresent(pushData, "profileId", notification.getProfileId());
    putIfPresent(pushData, "targetId", notification.getTargetId());
    return pushData;
  }

  private void putIfPresent(Map<String, String> data, String key, String value) {
    if (value != null && !value.isBlank()) {
      data.put(key, value);
    }
  }

  // 언어 > en 순서로 키를 찾음
  private String text(AppLocale locale, String key) {
    String text = bundle(locale).getProperty(key);
    if (text == null && locale != AppLocale.EN) {
      log.warn("[notification push] missing copy key : {}", key);
      text = bundle(AppLocale.EN).getProperty(key);
    }
    return text == null ? key : text;
  }

  private Properties bundle(AppLocale locale) {
    return bundleByLocale.computeIfAbsent(locale, this::loadBundle);
  }

  private Properties loadBundle(AppLocale locale) {
    Properties properties = new Properties();
    String resource = BUNDLE_RESOURCE.formatted(locale.code());
    try (InputStream stream = getClass().getClassLoader().getResourceAsStream(resource)) {
      if (stream != null) {
        properties.load(new InputStreamReader(stream, StandardCharsets.UTF_8));
      }
    } catch (IOException exception) {
      log.warn("[notification push] copy bundle unreadable : {}", resource);
    }
    return properties;
  }
}
