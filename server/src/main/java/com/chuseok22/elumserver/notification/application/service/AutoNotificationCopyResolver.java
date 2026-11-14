package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.ClasspathLocaleBundle;
import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import com.chuseok22.elumserver.notification.infrastructure.entity.AdminMessage;
import com.chuseok22.elumserver.notification.infrastructure.entity.AutoNotificationRule;
import com.chuseok22.elumserver.notification.infrastructure.entity.PushDevice;
import com.chuseok22.elumserver.notification.infrastructure.repository.PushDeviceRepository;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 자동 알림 문구 언어 고르기 (#1409): 받는 사람 언어 > 제목·본문 틀 > 변수 채우기
 * 언어 = 가장 최근 등록한 보호자 기기 언어 (기기 없으면 ko). ko 는 관리자가 고친 규칙 틀, 그 외 언어는 push-messages 파일 기본 문구
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class AutoNotificationCopyResolver {

  // push-messages 키: push.auto.{종류}.title / .body, 언어별 기본 이름·일과·날짜 형식
  static final String AUTO_KEY_PREFIX = "push.auto.";
  static final String TITLE_KEY_SUFFIX = ".title";
  static final String BODY_KEY_SUFFIX = ".body";
  static final String DEFAULT_CHILD_NAME_KEY = "push.auto.default_child_name";
  static final String DEFAULT_ROUTINE_TITLE_KEY = "push.auto.default_routine_title";
  static final String DATE_PATTERN_KEY = "push.auto.date_pattern";
  // 관리자 미리 보기의 {날짜} 예시 (오늘 + 7일)
  private static final int PREVIEW_DATE_OFFSET_DAYS = 7;
  // 한 번에 묻는 회원 id 수 (in 절 길이 제한)
  private static final int MEMBER_ID_CHUNK_SIZE = 500;

  private final PushDeviceRepository pushDeviceRepository;
  // 언어별 문구 캐시
  private final Map<AppLocale, Map<String, String>> bundleByLocale = new ConcurrentHashMap<>();

  /// 받는 사람 한 명의 문구: 제목·본문 (최대 글자 수로 자름)
  public record RenderedCopy(String title, String body) {
  }

  /// 회원 id > 문구 언어 (보호자 기기 중 마지막 등록 기기 언어, 기기 없으면 ko)
  public Map<String, AppLocale> localesOf(Collection<String> memberIds) {
    List<String> distinctMemberIds = memberIds.stream().distinct().toList();
    Map<String, PushDevice> latestDeviceByMemberId = new HashMap<>();
    for (int from = 0; from < distinctMemberIds.size(); from += MEMBER_ID_CHUNK_SIZE) {
      List<String> chunk = new ArrayList<>(
        distinctMemberIds.subList(from, Math.min(from + MEMBER_ID_CHUNK_SIZE, distinctMemberIds.size())));
      for (PushDevice device : pushDeviceRepository.findAllByMemberIdInAndLinkIdIsNull(chunk)) {
        latestDeviceByMemberId.merge(device.getMemberId(), device, AutoNotificationCopyResolver::laterRegistered);
      }
    }
    Map<String, AppLocale> localeByMemberId = new HashMap<>();
    for (String memberId : distinctMemberIds) {
      PushDevice device = latestDeviceByMemberId.get(memberId);
      localeByMemberId.put(memberId, device == null || device.getLocale() == null ? AppLocale.KO : device.getLocale());
    }
    return localeByMemberId;
  }

  /// 규칙 + 받는 사람 + 언어 > 문구 (ko 외 언어에 키가 없으면 ko 규칙 틀)
  public RenderedCopy render(AutoNotificationRule rule, AutoNotificationCandidate candidate, AppLocale locale) {
    AutoNotificationTemplate.Fallbacks fallbacks = fallbacksOf(locale, candidate.date());
    String titleTemplate = templateOf(rule, locale, TITLE_KEY_SUFFIX, rule.getTitleTemplate());
    String bodyTemplate = templateOf(rule, locale, BODY_KEY_SUFFIX, rule.getBodyTemplate());
    return new RenderedCopy(
      AutoNotificationTemplate.render(titleTemplate, candidate, fallbacks, AdminMessage.TITLE_MAX_LENGTH),
      AutoNotificationTemplate.render(bodyTemplate, candidate, fallbacks, AdminMessage.BODY_MAX_LENGTH));
  }

  /// 관리자 미리 보기: ko 외 언어별 기본 문구 (이름·일과는 언어별 기본 말, 날짜는 오늘 + 7일)
  public Map<AppLocale, RenderedCopy> previewOtherLocales(AutoNotificationRule rule, LocalDate today) {
    AutoNotificationCandidate sample = new AutoNotificationCandidate(null, null, null,
      today.plusDays(PREVIEW_DATE_OFFSET_DAYS));
    Map<AppLocale, RenderedCopy> previewByLocale = new LinkedHashMap<>();
    for (AppLocale locale : AppLocale.values()) {
      if (locale != AppLocale.KO) {
        previewByLocale.put(locale, render(rule, sample, locale));
      }
    }
    return previewByLocale;
  }

  /// push-messages 키: push.auto.{종류}.title / .body
  static String templateKeyOf(AutoNotificationType type, String suffix) {
    return AUTO_KEY_PREFIX + type.name() + suffix;
  }

  private String templateOf(AutoNotificationRule rule, AppLocale locale, String suffix, String koreanTemplate) {
    if (locale == AppLocale.KO) {
      return koreanTemplate;
    }
    String template = text(locale, templateKeyOf(rule.getType(), suffix));
    if (template == null) {
      log.warn("[auto notification] missing copy key : locale={}, type={}", locale.code(), rule.getType());
      return koreanTemplate;
    }
    return template;
  }

  private AutoNotificationTemplate.Fallbacks fallbacksOf(AppLocale locale, LocalDate date) {
    return new AutoNotificationTemplate.Fallbacks(
      nullToEmpty(text(locale, DEFAULT_CHILD_NAME_KEY)),
      nullToEmpty(text(locale, DEFAULT_ROUTINE_TITLE_KEY)),
      formatDate(locale, date));
  }

  // 날짜 > 언어별 형식 (ko "2월 12일", en "Feb 12"), 형식이 깨졌으면 ISO 날짜
  private String formatDate(AppLocale locale, LocalDate date) {
    if (date == null) {
      return "";
    }
    String pattern = text(locale, DATE_PATTERN_KEY);
    if (pattern == null) {
      return date.toString();
    }
    try {
      return DateTimeFormatter.ofPattern(pattern, Locale.forLanguageTag(locale.code())).format(date);
    } catch (IllegalArgumentException exception) {
      log.warn("[auto notification] invalid date pattern : locale={}", locale.code());
      return date.toString();
    }
  }

  // 언어 > en 순서로 키를 찾음 (ko 는 ko 만: 한국어 사용자에게 영어가 새지 않게)
  private String text(AppLocale locale, String key) {
    for (AppLocale candidateLocale : locale.fallbackChain()) {
      String text = bundle(candidateLocale).get(key);
      if (text != null && !text.isBlank()) {
        return text;
      }
    }
    return null;
  }

  private Map<String, String> bundle(AppLocale locale) {
    return bundleByLocale.computeIfAbsent(locale,
      key -> ClasspathLocaleBundle.load(PushMessageFactory.BUNDLE_RESOURCE, key));
  }

  private static PushDevice laterRegistered(PushDevice left, PushDevice right) {
    Comparator<PushDevice> byRegisteredAt = Comparator.comparing(PushDevice::getLastRegisteredAt,
      Comparator.nullsFirst(Comparator.naturalOrder()));
    return byRegisteredAt.compare(left, right) >= 0 ? left : right;
  }

  private static String nullToEmpty(String text) {
    return text == null ? "" : text;
  }
}
