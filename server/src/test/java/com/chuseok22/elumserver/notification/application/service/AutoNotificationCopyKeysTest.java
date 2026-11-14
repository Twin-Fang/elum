package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.ClasspathLocaleBundle;
import com.chuseok22.elumserver.notification.core.AutoNotificationType;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 문구 파일에 키가 빠지면 그 언어 보호자에게 한국어 문구가 가고, 모르는 변수는 {..} 가 그대로 보인다 (#1409)
class AutoNotificationCopyKeysTest {

  private static final Pattern TEMPLATE_VARIABLE = Pattern.compile("\\{[^{}]*}");
  // 사용자를 아이·child 로 부르지 않음 (용어 규칙)
  private static final Pattern FORBIDDEN_WORDS = Pattern.compile("(?i)\\bchild|\\bkid|아이에게|子ども|子供|孩子|niñ");

  @Test
  @DisplayName("다섯 언어 모두 ko 의 푸시 키를 다 갖고, ko 외 언어는 자동 알림 9종 제목·본문이 있다")
  void everyLocale_hasAllKeys() {
    Map<String, String> korean = bundle(AppLocale.KO);
    assertThat(korean).containsKeys(AutoNotificationCopyResolver.DEFAULT_CHILD_NAME_KEY,
      AutoNotificationCopyResolver.DEFAULT_ROUTINE_TITLE_KEY, AutoNotificationCopyResolver.DATE_PATTERN_KEY);
    for (AppLocale locale : AppLocale.values()) {
      Map<String, String> texts = bundle(locale);
      assertThat(texts).as(locale.code()).containsKeys(korean.keySet().toArray(String[]::new));
      if (locale == AppLocale.KO) {
        continue;
      }
      for (AutoNotificationType type : AutoNotificationType.values()) {
        assertThat(texts).as(locale.code() + " " + type)
          .containsKeys(AutoNotificationCopyResolver.templateKeyOf(type, AutoNotificationCopyResolver.TITLE_KEY_SUFFIX),
            AutoNotificationCopyResolver.templateKeyOf(type, AutoNotificationCopyResolver.BODY_KEY_SUFFIX));
      }
    }
  }

  @Test
  @DisplayName("자동 알림 문구는 아는 변수만 쓰고, 사용자를 child·아이로 부르지 않고, 가운뎃점이 없다")
  void autoCopy_usesKnownVariablesAndGlossary() {
    for (AppLocale locale : AppLocale.values()) {
      bundle(locale).forEach((key, text) -> {
        if (!key.startsWith(AutoNotificationCopyResolver.AUTO_KEY_PREFIX)
          || key.equals(AutoNotificationCopyResolver.DATE_PATTERN_KEY)) {
          return;
        }
        Matcher matcher = TEMPLATE_VARIABLE.matcher(text);
        while (matcher.find()) {
          assertThat(AutoNotificationTemplate.VARIABLES).as(locale.code() + " " + key).contains(matcher.group());
        }
        assertThat(FORBIDDEN_WORDS.matcher(text).find()).as(locale.code() + " " + key + " : " + text).isFalse();
        assertThat(text).as(locale.code() + " " + key).doesNotContain("·");
      });
    }
  }

  @Test
  @DisplayName("언어별 날짜 형식이 올바른 형식이다 (깨지면 ISO 날짜로 나감)")
  void datePattern_isValidPerLocale() {
    for (AppLocale locale : AppLocale.values()) {
      String pattern = bundle(locale).get(AutoNotificationCopyResolver.DATE_PATTERN_KEY);
      assertThat(pattern).as(locale.code()).isNotBlank();
      DateTimeFormatter.ofPattern(pattern, Locale.forLanguageTag(locale.code()));
    }
  }

  private static Map<String, String> bundle(AppLocale locale) {
    return ClasspathLocaleBundle.load(PushMessageFactory.BUNDLE_RESOURCE, locale);
  }
}
