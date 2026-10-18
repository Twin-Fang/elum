package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.logging.properties.HttpLoggingProperties;
import java.io.IOException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.env.YamlPropertySourceLoader;
import org.springframework.boot.context.properties.source.ConfigurationPropertySources;
import org.springframework.core.env.MutablePropertySources;
import org.springframework.core.io.ClassPathResource;

/**
 * 운영 로그에 요청·응답 헤더(Bearer 토큰)와 본문(보호자 원문)이 남지 않게 고정
 * 스프링을 띄우지 않고 application.yml 을 HttpLoggingProperties 로 바인딩
 */
class HttpLoggingPropertiesBindingTest {

  private static final String LOGGING_PROPERTIES_PREFIX = "chuseok22.logging";

  @Test
  @DisplayName("HTTP 요청·응답의 헤더와 본문 로그는 꺼져 있고 로깅 자체는 켜져 있다")
  void httpHeadersAndBodiesAreNotLogged() throws IOException {
    HttpLoggingProperties properties = bindFromApplicationYml();

    assertThat(properties.isLogRequestHeaders()).as("authorization 토큰이 로그에 남는다").isFalse();
    assertThat(properties.isLogRequestBody()).as("보호자 원문이 로그에 남는다").isFalse();
    assertThat(properties.isLogResponseHeaders()).isFalse();
    assertThat(properties.isLogResponseBody()).as("응답의 원문이 로그에 남는다").isFalse();
    // 꺼지면 요청 식별자·실행시간 로그까지 사라짐
    assertThat(properties.isEnabled()).isTrue();
  }

  private HttpLoggingProperties bindFromApplicationYml() throws IOException {
    MutablePropertySources sources = new MutablePropertySources();
    new YamlPropertySourceLoader().load("application", new ClassPathResource("application.yml"))
      .forEach(sources::addLast);
    return new Binder(ConfigurationPropertySources.from(sources))
      .bind(LOGGING_PROPERTIES_PREFIX, HttpLoggingProperties.class)
      .get();
  }
}
