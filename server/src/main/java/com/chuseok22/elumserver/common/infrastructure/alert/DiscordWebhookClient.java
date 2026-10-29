package com.chuseok22.elumserver.common.infrastructure.alert;

import com.chuseok22.elumserver.common.application.alert.IncidentAlertSender;
import com.chuseok22.elumserver.common.infrastructure.json.DefaultJsonMapper;
import com.chuseok22.elumserver.common.infrastructure.properties.IncidentAlertProperties;
import com.fasterxml.jackson.core.JsonProcessingException;
import java.net.URI;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientResponseException;

/**
 * Discord 웹훅 발송: 문구 > {content, allowed_mentions 없음} JSON > POST (#648)
 * 웹훅 주소에 토큰이 들어 있어 주소·예외 문구는 로그에 남기지 않음 (상태 코드·예외 이름만)
 */
@Slf4j
@Component
public class DiscordWebhookClient implements IncidentAlertSender {

  // Discord 메시지 content 최대 길이 (자)
  private static final int DISCORD_CONTENT_MAX_LENGTH = 2000;
  private static final String TRUNCATED_SUFFIX = "…";
  private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(5);
  private static final Duration READ_TIMEOUT = Duration.ofSeconds(10);

  private final String webhookUrl;
  private final RestClient restClient;

  public DiscordWebhookClient(IncidentAlertProperties properties) {
    this.webhookUrl = properties.discordWebhookUrl();
    HttpClient httpClient = HttpClient.newBuilder().connectTimeout(CONNECT_TIMEOUT).build();
    JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory(httpClient);
    requestFactory.setReadTimeout(READ_TIMEOUT);
    this.restClient = RestClient.builder().requestFactory(requestFactory).build();
  }

  @Override
  public void send(String message) {
    if (webhookUrl.isEmpty()) {
      return;
    }
    try {
      restClient.post()
        .uri(URI.create(webhookUrl))
        .contentType(MediaType.APPLICATION_JSON)
        .body(toPayloadJson(message))
        .retrieve()
        .toBodilessEntity();
    } catch (RestClientResponseException e) {
      log.warn("[incident alert] discord rejected : status={}", e.getStatusCode().value());
    } catch (JsonProcessingException | RuntimeException e) {
      log.warn("[incident alert] discord send failed : error={}", e.getClass().getSimpleName());
    }
  }

  // allowed_mentions.parse 비움 > 문구에 @everyone 이 섞여도 멘션 안 됨
  private static String toPayloadJson(String message) throws JsonProcessingException {
    Map<String, Object> payload = Map.of(
      "content", truncate(message == null ? "" : message),
      "allowed_mentions", Map.of("parse", List.of())
    );
    return DefaultJsonMapper.SHARED.writeValueAsString(payload);
  }

  private static String truncate(String message) {
    if (message.length() <= DISCORD_CONTENT_MAX_LENGTH) {
      return message;
    }
    return message.substring(0, DISCORD_CONTENT_MAX_LENGTH - TRUNCATED_SUFFIX.length()) + TRUNCATED_SUFFIX;
  }
}
