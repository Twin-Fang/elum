package com.chuseok22.elumserver.common.infrastructure.config;

import java.util.concurrent.Executor;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/**
 * 비동기 실행 설정: 알림 기록·푸시 전용 스레드풀
 * 요청 스레드와 분리 > 알림 지연·실패가 본래 요청에 번지지 않음
 */
@Configuration
@EnableAsync
public class AsyncConfig {

  public static final String NOTIFICATION_EXECUTOR = "notificationExecutor";

  private static final int NOTIFICATION_CORE_POOL_SIZE = 2;
  private static final int NOTIFICATION_MAX_POOL_SIZE = 4;
  // 대기 작업 최대 개수 (넘으면 호출 스레드에서 실행)
  private static final int NOTIFICATION_QUEUE_CAPACITY = 500;

  @Bean(name = NOTIFICATION_EXECUTOR)
  public Executor notificationExecutor() {
    ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
    executor.setCorePoolSize(NOTIFICATION_CORE_POOL_SIZE);
    executor.setMaxPoolSize(NOTIFICATION_MAX_POOL_SIZE);
    executor.setQueueCapacity(NOTIFICATION_QUEUE_CAPACITY);
    executor.setThreadNamePrefix("notification-");
    executor.initialize();
    return executor;
  }
}
