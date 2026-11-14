package com.chuseok22.elumserver.common.locale;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
import lombok.extern.slf4j.Slf4j;

/**
 * 클래스패스 언어별 문구 파일 > 키·문구 맵 (UTF-8)
 * 경로 형식 예: i18n/push-messages_%s.properties (%s 에 언어 코드). 없거나 못 읽으면 빈 맵
 */
@Slf4j
public final class ClasspathLocaleBundle {

  private ClasspathLocaleBundle() {
  }

  public static Map<String, String> load(String resourcePattern, AppLocale locale) {
    String resource = resourcePattern.formatted(locale.code());
    try (InputStream stream = ClasspathLocaleBundle.class.getClassLoader().getResourceAsStream(resource)) {
      if (stream == null) {
        return Map.of();
      }
      Properties properties = new Properties();
      properties.load(new InputStreamReader(stream, StandardCharsets.UTF_8));
      Map<String, String> textByKey = new HashMap<>();
      properties.stringPropertyNames().forEach(key -> textByKey.put(key, properties.getProperty(key)));
      return Map.copyOf(textByKey);
    } catch (IOException exception) {
      log.warn("[locale bundle] unreadable : {}", resource, exception);
      return Map.of();
    }
  }
}
