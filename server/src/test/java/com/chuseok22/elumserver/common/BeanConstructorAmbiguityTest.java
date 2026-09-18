package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import java.lang.reflect.Constructor;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider;
import org.springframework.core.type.filter.AnnotationTypeFilter;
import org.springframework.stereotype.Component;
import org.springframework.stereotype.Controller;
import org.springframework.stereotype.Repository;
import org.springframework.stereotype.Service;

/**
 * 스프링이 어떤 생성자로 만들지 분명한지 확인한다.
 *
 * <p>생성자가 둘 이상인데 인자 없는 생성자도, {@code @Autowired}도 없으면 스프링은
 * 무엇을 쓸지 정하지 못하고 <b>서버 기동이 통째로 실패한다.</b> 컨트롤러 하나가 아니라
 * 애플리케이션 전체가 뜨지 않는다.
 *
 * <p>실제로 겪었다 — 쿨다운 가드를 공유 저장소 위로 옮기면서 인자 없는 생성자가
 * 사라졌고, 컴파일도 단위 테스트도 전부 통과한 채 배포돼 운영 서버가 내려갔다.
 *
 * <p>스프링 컨텍스트를 띄우지 않고 클래스만 훑는다. 통합 테스트가 아니라서 빠르고,
 * 이 저장소의 "단위 테스트만" 규칙에도 어긋나지 않는다.
 */
class BeanConstructorAmbiguityTest {

  private static final String BASE_PACKAGE = "com.chuseok22.elumserver";

  @Test
  @DisplayName("빈으로 등록되는 클래스는 스프링이 쓸 생성자가 분명해야 한다")
  void everyBeanHasUnambiguousConstructor() {
    List<String> ambiguous = new ArrayList<>();

    for (Class<?> type : scanBeanTypes()) {
      Constructor<?>[] constructors = type.getDeclaredConstructors();
      if (constructors.length <= 1) {
        continue;
      }
      boolean hasNoArg = Arrays.stream(constructors).anyMatch(c -> c.getParameterCount() == 0);
      boolean hasAutowired = Arrays.stream(constructors)
        .anyMatch(c -> c.isAnnotationPresent(Autowired.class));
      if (!hasNoArg && !hasAutowired) {
        ambiguous.add("%s — 생성자 %d개, 인자 없는 생성자도 @Autowired도 없음"
          .formatted(type.getName(), constructors.length));
      }
    }

    assertThat(ambiguous)
      .as("생성자가 여러 개면 스프링이 쓸 것을 @Autowired로 짚어줘야 한다. "
        + "빠뜨리면 서버가 아예 뜨지 않는다")
      .isEmpty();
  }

  private List<Class<?>> scanBeanTypes() {
    ClassPathScanningCandidateComponentProvider scanner =
      new ClassPathScanningCandidateComponentProvider(false);
    scanner.addIncludeFilter(new AnnotationTypeFilter(Component.class));
    scanner.addIncludeFilter(new AnnotationTypeFilter(Service.class));
    scanner.addIncludeFilter(new AnnotationTypeFilter(Repository.class));
    scanner.addIncludeFilter(new AnnotationTypeFilter(Controller.class));

    List<Class<?>> types = new ArrayList<>();
    scanner.findCandidateComponents(BASE_PACKAGE).forEach(definition -> {
      try {
        types.add(Class.forName(definition.getBeanClassName()));
      } catch (ClassNotFoundException e) {
        throw new IllegalStateException("스캔한 클래스를 불러오지 못했다: "
          + definition.getBeanClassName(), e);
      }
    });
    return types;
  }
}
