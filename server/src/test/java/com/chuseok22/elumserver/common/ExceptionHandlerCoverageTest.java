package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.exception.AdminViewExceptionHandler;
import com.chuseok22.elumserver.common.application.exception.GlobalExceptionHandler;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider;
import org.springframework.core.type.filter.AnnotationTypeFilter;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RestControllerAdvice;

/**
 * 모든 컨트롤러의 예외가 어느 한 핸들러에 잡히는지 (이슈 #370).
 *
 * <p>{@link GlobalExceptionHandler} 는 패키지 목록으로 범위를 좁혀 둔다. 새 도메인 패키지를
 * 만들고 목록에 더하지 않으면 {@code CustomException} 이 잡히지 않아 <b>400·404 여야 할 응답이
 * 500 으로 나간다.</b> 컴파일도 단위 테스트도 통과하므로 실제로 불러 봐야 드러난다 — #200 에서
 * link 패키지가 그렇게 빠져 있었다. 관리자 화면 쪽({@link AdminViewExceptionHandler})도
 * 컨트롤러를 하나씩 적으므로 같은 함정이 있다.
 *
 * <p>스프링을 띄우지 않고 클래스만 훑는다.
 */
class ExceptionHandlerCoverageTest {

  private static final String BASE_PACKAGE = "com.chuseok22.elumserver";

  @Test
  @DisplayName("REST 컨트롤러는 전부 GlobalExceptionHandler 범위 안에 있다")
  void everyRestControllerIsCovered() {
    RestControllerAdvice advice = GlobalExceptionHandler.class.getAnnotation(RestControllerAdvice.class);
    List<String> packages = Arrays.asList(advice.basePackages());
    List<Class<?>> types = Arrays.asList(advice.assignableTypes());

    List<String> missing = new ArrayList<>();
    for (Class<?> controller : scan(RestController.class)) {
      boolean coveredByPackage = packages.stream()
        .anyMatch(pkg -> controller.getPackageName().equals(pkg) || controller.getPackageName().startsWith(pkg + "."));
      boolean coveredByType = types.stream().anyMatch(type -> type.isAssignableFrom(controller));
      if (!coveredByPackage && !coveredByType) {
        missing.add(controller.getName());
      }
    }

    assertThat(missing)
      .as("GlobalExceptionHandler basePackages 에 이 패키지를 더한다. 빠뜨리면 400 이 500 으로 나간다")
      .isEmpty();
  }

  @Test
  @DisplayName("관리자 화면 컨트롤러는 전부 AdminViewExceptionHandler 가 맡는다")
  void everyAdminViewControllerIsCovered() {
    ControllerAdvice advice = AdminViewExceptionHandler.class.getAnnotation(ControllerAdvice.class);
    List<Class<?>> types = Arrays.asList(advice.assignableTypes());

    List<String> missing = new ArrayList<>();
    for (Class<?> controller : scan(Controller.class)) {
      boolean isAdminView = controller.getPackageName().startsWith(BASE_PACKAGE + ".admin")
        && !controller.isAnnotationPresent(RestController.class);
      if (isAdminView && types.stream().noneMatch(type -> type.isAssignableFrom(controller))) {
        missing.add(controller.getName());
      }
    }

    assertThat(missing)
      .as("AdminViewExceptionHandler assignableTypes 에 더한다. 빠뜨리면 없는 항목 주소가 404 가 아니라 500 이 된다")
      .isEmpty();
  }

  private List<Class<?>> scan(Class<? extends java.lang.annotation.Annotation> annotation) {
    ClassPathScanningCandidateComponentProvider scanner = new ClassPathScanningCandidateComponentProvider(false);
    scanner.addIncludeFilter(new AnnotationTypeFilter(annotation));
    List<Class<?>> found = new ArrayList<>();
    scanner.findCandidateComponents(BASE_PACKAGE).forEach(definition -> {
      try {
        found.add(Class.forName(definition.getBeanClassName()));
      } catch (ClassNotFoundException e) {
        throw new IllegalStateException(definition.getBeanClassName(), e);
      }
    });
    assertThat(found).as("스캔이 비면 이 테스트가 아무것도 보지 않은 것이다").isNotEmpty();
    return found;
  }
}
