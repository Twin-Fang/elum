package com.chuseok22.elumserver.common.infrastructure.config;

import java.util.concurrent.Executor;
import java.util.concurrent.ThreadPoolExecutor;
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
  // 대기 작업 최대 개수 (넘치면 호출 스레드에서 실행)
  private static final int NOTIFICATION_QUEUE_CAPACITY = 500;
  // 종료 시 대기 작업을 마무리할 최대 시간 (초)
  private static final int NOTIFICATION_AWAIT_TERMINATION_SECONDS = 10;

  @Bean(name = NOTIFICATION_EXECUTOR)
  public Executor notificationExecutor() {
    ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
    executor.setCorePoolSize(NOTIFICATION_CORE_POOL_SIZE);
    executor.setMaxPoolSize(NOTIFICATION_MAX_POOL_SIZE);
    executor.setQueueCapacity(NOTIFICATION_QUEUE_CAPACITY);
    // 가득 차도 거부 예외로 이미 커밋된 요청이 500 이 되지 않게 호출 스레드에서 실행
    executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
    // 배포 중 대기 중인 알림 기록이 버려지지 않게 종료를 기다림
    executor.setWaitForTasksToCompleteOnShutdown(true);
    executor.setAwaitTerminationSeconds(NOTIFICATION_AWAIT_TERMINATION_SECONDS);
    executor.setThreadNamePrefix("notification-");
    executor.initialize();
    return executor;
  }
}
