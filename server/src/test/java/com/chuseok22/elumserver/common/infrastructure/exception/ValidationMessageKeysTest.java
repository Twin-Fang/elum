package com.chuseok22.elumserver.common.infrastructure.exception;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.beans.Introspector;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.lang.annotation.Annotation;
import java.lang.reflect.Field;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider;
import org.springframework.core.type.filter.RegexPatternTypeFilter;

/**
 * request DTO 의 {@code message} 문구와 ko 리소스가 같은 글자인지 대조한다 (다국어 #526).
 *
 * <p>DTO 의 문구가 {@code FieldError.getDefaultMessage()} 로 나가는 지금 응답이 원본이다. ko 리소스를 따로 두는 이유는
 * 다른 언어 번역을 같은 키 체계로 받기 위해서이고, 둘이 어긋나면 헤더 없는 앱의 응답이 바뀐다.
 * 새 DTO 에 message 를 적으면 여기서 걸린다 — 키를 ko 리소스에 더해야 번역이 들어갈 자리가 생긴다.
 */
class ValidationMessageKeysTest {

  private record Constraint(String key, String message) {
  }

  private static List<Constraint> literalConstraints() throws Exception {
    ClassPathScanningCandidateComponentProvider scanner = new ClassPathScanningCandidateComponentProvider(false);
    scanner.addIncludeFilter(new RegexPatternTypeFilter(Pattern.compile(".*\\.dto\\.request\\..+")));
    List<Constraint> found = new ArrayList<>();
    for (BeanDefinition definition : scanner.findCandidateComponents("com.chuseok22.elumserver")) {
      Class<?> type = Class.forName(definition.getBeanClassName());
      for (Field field : type.getDeclaredFields()) {
        for (Annotation annotation : field.getAnnotations()) {
          Class<? extends Annotation> annotationType = annotation.annotationType();
          if (!annotationType.getName().startsWith("jakarta.validation.constraints.")) {
            continue;
          }
          String message = (String) annotationType.getMethod("message").invoke(annotation);
          if (message.startsWith("{")) {
            continue; // message 를 안 적은 제약은 Hibernate Validator 기본 문구다 — 이 계획 범위 밖
          }
          found.add(new Constraint(
            "validation." + Introspector.decapitalize(type.getSimpleName()) + "." + field.getName() + "."
              + annotationType.getSimpleName(),
            message));
        }
      }
    }
    return found;
  }

  private static Properties koFile() throws Exception {
    Properties properties = new Properties();
    try (InputStream in = ValidationMessageKeysTest.class.getResourceAsStream("/i18n/messages_ko.properties")) {
      properties.load(new InputStreamReader(in, StandardCharsets.UTF_8));
    }
    return properties;
  }

  @Test
  @DisplayName("message 를 적은 제약이 17개 있고, 키가 서로 겹치지 않는다")
  void keysAreUnique() throws Exception {
    List<Constraint> found = literalConstraints();

    // 실제 개수를 코드로 센 값이다(계획 사전 점검: 13줄이 아니라 17줄)
    assertThat(found).hasSize(17);
    assertThat(found.stream().map(Constraint::key).toList()).doesNotHaveDuplicates();
  }

  @Test
  @DisplayName("ko 리소스는 DTO message 와 글자 하나까지 같다")
  void koResource_equalsDtoMessage() throws Exception {
    for (Constraint constraint : literalConstraints()) {
      assertThat(ErrorMessages.standard().of(constraint.key(), AppLocale.KO, "<<없음>>"))
        .as(constraint.key())
        .isEqualTo(constraint.message());
    }
  }

  @Test
  @DisplayName("ko 리소스의 validation.* 키는 DTO 에 실제로 있는 제약과 정확히 일치한다 — 쓰이지 않는 키가 남지 않는다")
  void koResourceKeys_matchDtoConstraints() throws Exception {
    Set<String> expected = literalConstraints().stream().map(Constraint::key).collect(Collectors.toSet());
    Set<String> inFile = koFile().stringPropertyNames().stream()
      .filter(key -> key.startsWith("validation."))
      .collect(Collectors.toSet());

    assertThat(inFile).containsExactlyInAnyOrderElementsOf(expected);
  }

  @Test
  @DisplayName("본문을 읽을 수 없을 때의 문구 키가 ko 리소스에 있다")
  void unreadableBodyKey_exists() {
    assertThat(ErrorMessages.standard().of("detail.requestBodyUnreadable", AppLocale.KO, "<<없음>>"))
      .isEqualTo("요청 본문을 읽을 수 없습니다.");
  }
}
