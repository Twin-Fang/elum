package com.chuseok22.elumserver.adreward;

import static org.assertj.core.api.Assertions.assertThat;

import java.lang.reflect.Constructor;
import java.time.Clock;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider;
import org.springframework.core.type.filter.AnnotationTypeFilter;
import org.springframework.stereotype.Component;

/**
 * 스프링이 실제로 쓸 생성자가 **없는 빈(Clock)을 요구하지 않는지** 본다 (#463).
 *
 * <p>이 앱에는 {@code Clock} 빈이 없다. 서비스가 {@code Clock} 을 생성자로 받으면 단위 테스트(직접 넘긴다)는 통과하는데
 * 서버가 기동에 실패한다 — 꺼 둔 기능 때문에 서버 전체가 죽는다. 그래서 다른 서비스처럼 "공개 생성자에서
 * {@code Clock.systemDefaultZone()} 을 넘기는 이중 생성자"를 쓴다. 이 테스트가 그 약속을 지킨다.
 */
class AdRewardBeanConstructionTest {

  @Test
  @DisplayName("광고 보상 빈은 스프링이 쓸 생성자에 Clock 을 요구하지 않는다")
  void springConstructorNeverRequiresClock() throws ClassNotFoundException {
    ClassPathScanningCandidateComponentProvider scanner = new ClassPathScanningCandidateComponentProvider(false);
    scanner.addIncludeFilter(new AnnotationTypeFilter(Component.class));

    List<String> offenders = new ArrayList<>();
    int beans = 0;
    for (BeanDefinition definition : scanner.findCandidateComponents("com.chuseok22.elumserver.adreward")) {
      beans++;
      Class<?> type = Class.forName(definition.getBeanClassName());
      Constructor<?> used = constructorSpringUses(type);
      if (Arrays.asList(used.getParameterTypes()).contains(Clock.class)) {
        offenders.add(type.getSimpleName());
      }
    }

    assertThat(beans).as("스캔이 헛돌지 않도록").isGreaterThanOrEqualTo(6);
    assertThat(offenders)
      .as("Clock 빈이 없다. @Autowired 공개 생성자에서 Clock.systemDefaultZone() 을 넘기는 이중 생성자로 만든다")
      .isEmpty();
  }

  /// 생성자가 하나면 그것, 여럿이면 @Autowired 가 붙은 것. (Spring 의 규칙)
  private static Constructor<?> constructorSpringUses(Class<?> type) {
    Constructor<?>[] all = type.getDeclaredConstructors();
    if (all.length == 1) {
      return all[0];
    }
    return Arrays.stream(all)
      .filter(c -> c.isAnnotationPresent(Autowired.class))
      .findFirst()
      .orElseThrow(() -> new AssertionError(type.getSimpleName() + " 는 생성자가 여럿인데 @Autowired 가 없다"));
  }
}
