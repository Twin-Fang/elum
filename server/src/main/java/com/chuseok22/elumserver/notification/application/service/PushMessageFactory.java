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

  // 언어별 문구 캐시
  private final Map<AppLocale, Properties> bundleByLocale = new ConcurrentHashMap<>();

  /** 알림 행 + 기록 결과 + 받는 기기 > 푸시 메시지 */
  public PushMessage create(Notification notification, RecordedNotification recorded, PushDevice device) {
    NotificationType type = notification.getType();
    AppLocale locale = device.getLocale() == null ? AppLocale.EN : device.getLocale();
    String title = text(locale, TITLE_KEY);
    String body = buildBody(type, recorded.count(), locale);
    return new PushMessage(device.getToken(), title, body, buildData(notification, type), notification.getGroupKey());
  }

  private String buildBody(NotificationType type, int count, AppLocale locale) {
    return switch (type) {
      case ROUTINE_COMPLETED -> count >= 2
        ? MessageFormat.format(text(locale, ROUTINE_COMPLETED_MANY_KEY), count)
        : text(locale, ROUTINE_COMPLETED_ONE_KEY);
      case ROUTINE_SENT_BY_CO_GUARDIAN -> text(locale, "push.routine_sent");
      case CO_GUARDIAN_JOINED -> text(locale, "push.co_guardian_joined");
      case CREDIT_REFILLED -> text(locale, "push.credit_refilled");
      case FEEDBACK_RESOLVED -> text(locale, "push.feedback_resolved");
    };
  }

  // data: 앱이 눌렀을 때 화면을 정하는 id 만 (없는 값은 빈 문자열)
  private Map<String, String> buildData(Notification notification, NotificationType type) {
    Map<String, String> data = new HashMap<>();
    data.put("type", type.name());
    data.put("notificationId", notification.getId());
    data.put("profileId", orEmpty(notification.getProfileId()));
    data.put("targetId", orEmpty(notification.getTargetId()));
    return data;
  }

  private String orEmpty(String value) {
    return value == null ? "" : value;
  }

  // 언어 > en 순서로 키를 찾음
  private String text(AppLocale locale, String key) {
    String text = bundle(locale).getProperty(key);
    if (text == null && locale != AppLocale.EN) {
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
