package com.chuseok22.elumserver.common.application.alert;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.infrastructure.logging.InstanceInfo;
import com.chuseok22.elumserver.common.infrastructure.properties.IncidentAlertProperties;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 장애 알림 발송 조건: 쿨다운 안 중복 억제, 웹훅 주소 없으면 꺼짐 (#648)
 * 실제 Discord 를 부르지 않음 (보낸 문구만 모으는 가짜 발송기 + 호출 스레드 즉시 실행)
 */
class IncidentAlertServiceTest {

  private static final Clock FIXED_CLOCK = Clock.fixed(Instant.parse("2026-10-29T05:00:00Z"), ZoneOffset.UTC);
  private static final InstanceInfo INSTANCE_INFO = new InstanceInfo("blue", "8085", "2.82.0", Instant.EPOCH);
  private static final String FAKE_WEBHOOK_URL = "https://discord.example/api/webhooks/test";

  private final List<String> sentMessages = new ArrayList<>();

  @Test
  @DisplayName("같은 원인 알림은 쿨다운 안에서 한 번만 보낸다 — 5xx 가 이어질 때 채널이 같은 알림으로 덮이지 않게")
  void notify_sameCauseWithinCooldown_sendsOnce() {
    IncidentAlertService service = newService(FAKE_WEBHOOK_URL);
    IncidentAlert alert = new IncidentAlert(IncidentAlertType.SERVER_ERROR_SURGE, "all", List.of());

    service.notify(alert);
    service.notify(alert);

    assertThat(sentMessages).hasSize(1);
  }

  @Test
  @DisplayName("웹훅 주소가 없으면 알림을 끄고 아무것도 보내지 않는다 — 주소 미등록 환경에서도 서버가 뜨고 요청이 깨지지 않게")
  void notify_webhookUrlEmpty_disabledAndSendsNothing() {
    IncidentAlertService service = newService("");

    service.notify(new IncidentAlert(IncidentAlertType.SERVER_ERROR_SURGE, "all", List.of()));

    assertThat(service.isEnabled()).isFalse();
    assertThat(sentMessages).isEmpty();
  }

  private IncidentAlertService newService(String webhookUrl) {
    IncidentAlertProperties properties = new IncidentAlertProperties(webhookUrl, "", null, null, null, null);
    return new IncidentAlertService(properties, sentMessages::add, Runnable::run, INSTANCE_INFO, FIXED_CLOCK);
  }
}
