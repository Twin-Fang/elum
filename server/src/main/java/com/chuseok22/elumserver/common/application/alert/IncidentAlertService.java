package com.chuseok22.elumserver.common.application.alert;

import com.chuseok22.elumserver.common.infrastructure.constant.SecurityPaths;
import com.chuseok22.elumserver.common.infrastructure.logging.InstanceInfo;
import com.chuseok22.elumserver.common.infrastructure.properties.IncidentAlertProperties;
import jakarta.annotation.PreDestroy;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.Executor;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.ThreadPoolExecutor;
import java.util.concurrent.TimeUnit;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/**
 * 장애 알림 발송 진입점: 켜짐 확인 > 쿨다운 확인 > 문구 조립 > 전용 스레드에서 발송 (#648)
 * 어떤 실패도 호출자(본 요청)로 넘기지 않음, 웹훅 주소가 없으면 기동 시 경고 1회 후 아무것도 안 함
 */
@Slf4j
@Service
public class IncidentAlertService {

  // 발송 대기 최대 개수 (넘치면 버리고 경고 로그, 요청 스레드에서 보내지 않음)
  private static final int SEND_QUEUE_CAPACITY = 100;
  // 종료 시 대기 발송을 기다리는 최대 시간 (초)
  private static final int SHUTDOWN_AWAIT_SECONDS = 5;
  private static final String SEND_THREAD_NAME = "incident-alert";
  // 운영 컨테이너 TZ 와 같은 한국 시각으로 표시
  private static final ZoneId ALERT_ZONE = ZoneId.of("Asia/Seoul");
  private static final DateTimeFormatter ALERT_TIME_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");
  private static final String MESSAGE_TITLE_PREFIX = "[ELUM 장애] ";

  private final boolean isEnabled;
  private final IncidentAlertSender sender;
  private final Executor sendExecutor;
  private final IncidentAlertCooldown cooldown = new IncidentAlertCooldown();
  private final Duration configuredCooldown;
  private final String serverLabel;
  private final String adminDashboardUrl;
  private final Clock clock;

  @Autowired
  public IncidentAlertService(
    IncidentAlertProperties properties, IncidentAlertSender sender, InstanceInfo instanceInfo
  ) {
    this(properties, sender, newSendExecutor(), instanceInfo, Clock.systemUTC());
  }

  IncidentAlertService(
    IncidentAlertProperties properties, IncidentAlertSender sender, Executor sendExecutor,
    InstanceInfo instanceInfo, Clock clock
  ) {
    this.isEnabled = isWebhookUsable(properties);
    this.sender = sender;
    this.sendExecutor = sendExecutor;
    this.configuredCooldown = properties.cooldown();
    this.serverLabel = instanceInfo.instance() + " · v" + instanceInfo.version();
    this.adminDashboardUrl = properties.adminBaseUrl().isEmpty()
      ? ""
      : properties.adminBaseUrl() + SecurityPaths.ADMIN_DASHBOARD;
    this.clock = clock;
  }

  public boolean isEnabled() {
    return isEnabled;
  }

  /** 알림 1건 요청 (꺼짐·쿨다운 안이면 버림, 발송은 비동기) */
  public void notify(IncidentAlert alert) {
    if (!isEnabled || alert == null) {
      return;
    }
    try {
      Instant now = clock.instant();
      Duration cooldownOfType = alert.type().cooldownOr(configuredCooldown);
      if (!cooldown.tryAcquire(alert.cooldownKey(), cooldownOfType, now)) {
        return;
      }
      String message = toMessage(alert, now);
      sendExecutor.execute(() -> sendSafely(alert.type(), message));
    } catch (RejectedExecutionException e) {
      log.warn("[incident alert] dropped : send queue full, type={}", alert.type());
    } catch (RuntimeException e) {
      log.warn("[incident alert] notify failed : type={}, error={}", alert.type(), e.getClass().getSimpleName());
    }
  }

  @PreDestroy
  void shutdownSendExecutor() {
    if (!(sendExecutor instanceof ExecutorService executorService)) {
      return;
    }
    executorService.shutdown();
    try {
      executorService.awaitTermination(SHUTDOWN_AWAIT_SECONDS, TimeUnit.SECONDS);
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
    }
  }

  // 켜짐 조건 2개: 주소 있음, https (꺼짐 사유는 기동 시 1회만 경고, 주소 값은 남기지 않음)
  private static boolean isWebhookUsable(IncidentAlertProperties properties) {
    if (!properties.hasDiscordWebhookUrl()) {
      log.warn("[incident alert] disabled : discord webhook url is empty (elum.incident-alert.discord-webhook-url)");
      return false;
    }
    if (!properties.isDiscordWebhookUrlHttps()) {
      log.warn("[incident alert] disabled : discord webhook url must start with https://");
      return false;
    }
    return true;
  }

  // 발송 실패 > 로그만 (본 요청과 무관한 스레드)
  private void sendSafely(IncidentAlertType type, String message) {
    try {
      sender.send(message);
    } catch (RuntimeException e) {
      log.warn("[incident alert] send failed : type={}, error={}", type, e.getClass().getSimpleName());
    }
  }

  // 문구: 제목 > 시각 > 서버 > 항목들 > 관리자 화면 링크
  private String toMessage(IncidentAlert alert, Instant now) {
    StringBuilder message = new StringBuilder()
      .append("**").append(MESSAGE_TITLE_PREFIX).append(alert.type().getLabel()).append("**\n")
      .append("시각: ").append(ALERT_TIME_FORMAT.format(now.atZone(ALERT_ZONE))).append(" (KST)\n")
      .append("서버: ").append(serverLabel).append('\n');
    for (IncidentAlert.Detail detail : alert.details()) {
      message.append(detail.name()).append(": ").append(detail.value()).append('\n');
    }
    if (!adminDashboardUrl.isEmpty()) {
      message.append("관리자 화면: ").append(adminDashboardUrl).append('\n');
    }
    return message.toString();
  }

  // 단일 스레드 + 대기 상한 (넘치면 RejectedExecutionException > notify 에서 경고 로그)
  private static ExecutorService newSendExecutor() {
    return new ThreadPoolExecutor(
      1, 1, 0L, TimeUnit.MILLISECONDS,
      new ArrayBlockingQueue<>(SEND_QUEUE_CAPACITY),
      runnable -> {
        Thread thread = new Thread(runnable, SEND_THREAD_NAME);
        thread.setDaemon(true);
        return thread;
      },
      new ThreadPoolExecutor.AbortPolicy()
    );
  }
}
