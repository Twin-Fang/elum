package com.chuseok22.elumserver.talk.infrastructure.web;

import com.chuseok22.elumserver.systemconfig.application.service.MigrationLock;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 공유 미리보기 이동 필터 등록: /s/* 에만 (API·관리자 경로는 타지 않음)
 */
@Configuration
public class MigrationShareRedirectFilterConfig {

  // TalkSharePageController 의 /s/{postId}, /s/{postId}/thumbnail
  private static final String SHARE_PAGE_URL_PATTERN = "/s/*";

  @Bean
  public FilterRegistrationBean<MigrationShareRedirectFilter> migrationShareRedirectFilterRegistration(
    MigrationLock migrationLock
  ) {
    FilterRegistrationBean<MigrationShareRedirectFilter> registration =
      new FilterRegistrationBean<>(new MigrationShareRedirectFilter(migrationLock));
    registration.addUrlPatterns(SHARE_PAGE_URL_PATTERN);
    return registration;
  }
}
