package com.chuseok22.elumserver.auth.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import com.chuseok22.elumserver.auth.application.service.AuthService;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;

@SuppressWarnings("removal")
class LegacyPasswordAuthControllerConditionTest {

  private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
    .withUserConfiguration(TestConfiguration.class);

  @Test
  void 기본값으로는_구형_비밀번호_인증_API를_만들지_않는다() {
    contextRunner.run(context ->
      assertThat(context).doesNotHaveBean(LegacyPasswordAuthController.class));
  }

  @Test
  void 개발자가_명시적으로_켰을_때만_구형_API를_만든다() {
    contextRunner
      .withPropertyValues("elum.auth.legacy-password.enabled=true")
      .run(context -> assertThat(context).hasSingleBean(LegacyPasswordAuthController.class));
  }

  @Test
  void 운영에서는_설정을_켜도_구형_API를_만들지_않는다() {
    contextRunner
      .withPropertyValues(
        "spring.profiles.active=prod",
        "elum.auth.legacy-password.enabled=true"
      )
      .run(context -> assertThat(context).doesNotHaveBean(LegacyPasswordAuthController.class));
  }

  @Configuration(proxyBeanMethods = false)
  @Import(LegacyPasswordAuthController.class)
  static class TestConfiguration {

    @Bean
    AuthService authService() {
      return mock(AuthService.class);
    }
  }
}
