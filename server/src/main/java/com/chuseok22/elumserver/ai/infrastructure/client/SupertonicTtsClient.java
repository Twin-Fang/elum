package com.chuseok22.elumserver.ai.infrastructure.client;

import com.chuseok22.elumserver.common.infrastructure.properties.LocalLlmProperties;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * AI 서버 Supertonic 음성 합성: 문장 > WAV (#675)
 * 주소·키는 local-llm 설정 공유 (같은 AI 서버, 같은 X-API-Key)
 */
@Slf4j
@Component
public class SupertonicTtsClient {

  // AI 서버 TTS 경로 (Flask)
  private static final String TTS_PATH = "/api/flask/tts";
  // CPU 전용이라 GPU "한 번에 1개" 정책과 무관하게 상시 가동
  private static final String ENGINE = "supertonic";
  // 여성 1 (앱 RemoteSpeech 와 같은 목소리)
  private static final String VOICE = "F1";
  // AI 서버 문장 길이 제한 (넘기면 400)
  private static final int MAX_TEXT_LENGTH = 500;
  private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(3);
  // 실측 한 건 2.3~3.5초. 대기열이 하나씩 보내므로 넉넉히
  private static final Duration READ_TIMEOUT = Duration.ofSeconds(30);
  // 요청 중 즉석 합성용 (앱 받기 대기 상한 8초 안에 끝나야 함 > 넘기면 404 로 넘김)
  public static final Duration ON_DEMAND_READ_TIMEOUT = Duration.ofSeconds(6);

  private final RestClient restClient;
  private final RestClient onDemandRestClient;
  private final LocalLlmProperties localLlmProperties;

  public SupertonicTtsClient(LocalLlmProperties localLlmProperties) {
    this.localLlmProperties = localLlmProperties;
    this.restClient = buildRestClient(READ_TIMEOUT);
    this.onDemandRestClient = buildRestClient(ON_DEMAND_READ_TIMEOUT);
  }

  private RestClient buildRestClient(Duration readTimeout) {
    JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory(
      HttpClient.newBuilder().connectTimeout(CONNECT_TIMEOUT).build());
    requestFactory.setReadTimeout(readTimeout);
    return RestClient.builder()
      .baseUrl(localLlmProperties.baseUrl())
      .requestFactory(requestFactory)
      .build();
  }

  /**
   * 키가 있을 때만 호출 가능
   */
  public boolean isAvailable() {
    String apiKey = localLlmProperties.apiKey();
    return apiKey != null && !apiKey.isBlank();
  }

  /**
   * 문장 > WAV. 실패·빈 응답은 예외 (호출부가 기록하고 넘어감)
   */
  public byte[] synthesize(String text) {
    return post(restClient, text);
  }

  /**
   * 문장 > WAV, 읽기 제한 6초 (요청 중 즉석 합성용)
   */
  public byte[] synthesizeWithinOnDemandLimit(String text) {
    return post(onDemandRestClient, text);
  }

  private byte[] post(RestClient client, String text) {
    String clippedText = clip(text);
    byte[] wav = client.post()
      .uri(TTS_PATH)
      .header("X-API-Key", localLlmProperties.apiKey())
      .contentType(MediaType.APPLICATION_JSON)
      .body(Map.of("text", clippedText, "engine", ENGINE, "voice", VOICE))
      .retrieve()
      .body(byte[].class);
    if (wav == null || wav.length == 0) {
      throw new IllegalStateException("empty tts response");
    }
    return wav;
  }

  /**
   * 500자 초과분 자르기. 이모지 등 두 칸 글자가 반으로 잘리면 JSON 이 깨져 같은 400 이 반복되므로 한 칸 물림
   */
  static String clip(String text) {
    if (text.length() <= MAX_TEXT_LENGTH) {
      return text;
    }
    int end = MAX_TEXT_LENGTH;
    if (Character.isHighSurrogate(text.charAt(end - 1))) {
      end--;
    }
    return text.substring(0, end);
  }
}
