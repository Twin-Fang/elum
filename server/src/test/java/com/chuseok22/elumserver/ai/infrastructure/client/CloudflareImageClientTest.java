package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withStatus;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.Base64;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

/// 실제 Cloudflare 를 부르지 않는다. 보내는 본문·프롬프트·한도 소진 처리만 본다
class CloudflareImageClientTest {

  private static final String ACCOUNT_ID = "acct0000000000000000000000000001";
  private static final String TOKEN = "secret-token-value";
  private static final String MODEL = "@cf/black-forest-labs/flux-2-klein-4b";
  private static final String RUN_URL = "https://api.cloudflare.com/client/v4/accounts/" + ACCOUNT_ID + "/ai/run/" + MODEL;
  private static final String CHILD = "a simple cartoon child with short black bowl-cut hair";

  private final PromptTemplateService promptTemplateService = mock(PromptTemplateService.class);
  private final SystemConfigService systemConfigService = mock(SystemConfigService.class);
  private final AiCallLogService aiCallLogService = mock(AiCallLogService.class);
  private final MutableClock clock = new MutableClock(Instant.parse("2026-11-11T08:00:00Z"));
  private MockRestServiceServer server;
  private CloudflareImageClient client;

  @BeforeEach
  void setUp() {
    RestClient.Builder builder = RestClient.builder().baseUrl("https://api.cloudflare.com/client/v4");
    server = MockRestServiceServer.bindTo(builder).build();
    client = new CloudflareImageClient(promptTemplateService, new FluxPromptBuilder(), systemConfigService,
      aiCallLogService, builder.build(), clock);
    when(promptTemplateService.getContent(PromptKey.FLUX_ROUTINE_IMAGE_PREFIX)).thenReturn("Flat vector.");
    when(promptTemplateService.getContent(PromptKey.CARD_IMAGE_SUBJECT_CHILD)).thenReturn(CHILD);
    when(systemConfigService.getString(ConfigKey.CLOUDFLARE_IMAGE_MODEL)).thenReturn(MODEL);
    when(systemConfigService.getString(ConfigKey.CLOUDFLARE_ACCOUNT_ID)).thenReturn(ACCOUNT_ID);
    when(systemConfigService.getSecret(ConfigKey.CLOUDFLARE_API_TOKEN)).thenReturn(TOKEN);
  }

  @Test
  @DisplayName("512x376 · seed · 프롬프트 그대로 — 크기가 바뀌면 카드 칸 비율이 어긋난다")
  void parts_sizeSeedPrompt() {
    var parts = client.requestParts("prompt", 1001);

    assertThat(parts.getFirst("width")).isEqualTo("512");
    assertThat(parts.getFirst("height")).isEqualTo("376");
    assertThat(parts.getFirst("seed")).isEqualTo("1001");
    assertThat(parts.getFirst("prompt")).isEqualTo("prompt");
    assertThat(client.requestParts("prompt", null).containsKey("seed")).isFalse();
  }

  @Test
  @DisplayName("루루를 골랐어도 카드 그림은 만화 아이로 — 캐릭터 생김새가 섞이면 고양이가 그려진다")
  void generate_usesChildNotProfileCharacter() {
    String prompt = client.buildCartoonPrompt("Flat vector.", "The character brushes the teeth.", CharacterType.LULU);

    assertThat(prompt).isEqualTo("Flat vector. Only one character: " + CHILD + ". The child brushes the teeth.");
    assertThat(prompt).doesNotContain("kitten").doesNotContain(CharacterType.LULU.getAppearanceEn());
  }

  @Test
  @DisplayName("성공 응답 base64 > 그림 바이트, JPEG 는 jpg 로 저장하고 호출 기록을 남긴다")
  void generate_success_decodesImage() {
    byte[] jpeg = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, 1, 2};
    server.expect(requestTo(RUN_URL)).andRespond(withSuccess(
      "{\"result\":{\"image\":\"" + Base64.getEncoder().encodeToString(jpeg) + "\"},\"success\":true}",
      MediaType.APPLICATION_JSON));

    GeneratedImage image = client.generate("The character waves.", CharacterType.POPO, 7);

    assertThat(image.bytes()).isEqualTo(jpeg);
    assertThat(image.extension()).isEqualTo("jpg");
    verify(aiCallLogService).recordSuccess(eq(AiCallType.CLOUDFLARE_IMAGE), eq(MODEL), anyLong(), eq(null));
    server.verify();
  }

  @Test
  @DisplayName("하루 무료 한도 소진(4006) 뒤 같은 날은 부르지 않고 바로 실패, 00:00 UTC 부터 다시 부른다")
  void quota4006_skipsUntilNextUtcMidnight() {
    server.expect(requestTo(RUN_URL)).andRespond(withStatus(HttpStatus.TOO_MANY_REQUESTS)
      .contentType(MediaType.APPLICATION_JSON)
      .body("{\"errors\":[{\"message\":\"you have used up your daily free allocation\",\"code\":4006}],\"success\":false}"));

    assertThatThrownBy(() -> client.generate("The character waves.", null, 1)).isInstanceOf(IllegalStateException.class);
    // 두 번째 카드: HTTP 없이 실패 (server 에 기대 요청이 하나뿐)
    assertThatThrownBy(() -> client.generate("The character waves.", null, 1)).isInstanceOf(IllegalStateException.class);
    server.verify();

    clock.set(Instant.parse("2026-11-11T23:59:59Z"));
    assertThat(client.isQuotaExhausted()).isTrue();
    assertThat(client.isTemporarilySkipped()).isTrue();
    clock.set(Instant.parse("2026-11-12T00:00:00Z"));
    assertThat(client.isQuotaExhausted()).isFalse();
  }

  @Test
  @DisplayName("실패 기록·예외에 토큰과 계정 ID 가 들어가지 않는다")
  void failureMessage_hasNoSecret() {
    server.expect(requestTo(RUN_URL)).andRespond(withStatus(HttpStatus.BAD_REQUEST)
      .contentType(MediaType.APPLICATION_JSON)
      .body("{\"errors\":[{\"message\":\"Input prompt contains NSFW content. " + ACCOUNT_ID + "\",\"code\":8007}]}"));

    assertThatThrownBy(() -> client.generate("The character holds a towel.", null, 1))
      .isInstanceOf(IllegalStateException.class)
      .hasMessageNotContaining(TOKEN)
      .hasMessageNotContaining(ACCOUNT_ID)
      .hasMessageContaining("8007");
    ArgumentCaptor<String> message = ArgumentCaptor.forClass(String.class);
    verify(aiCallLogService).recordFailure(eq(AiCallType.CLOUDFLARE_IMAGE), eq(MODEL), anyLong(), message.capture());
    assertThat(message.getValue()).isEqualTo("status=400, code=8007");
    // NSFW 는 한도 소진이 아니다 — 다음 카드는 다시 부른다
    assertThat(client.isQuotaExhausted()).isFalse();
  }

  @Test
  @DisplayName("토큰과 계정 ID 가 둘 다 있어야 고를 수 있다 — 하나라도 비면 관리자 화면이 막는다")
  void available_needsTokenAndAccount() {
    when(systemConfigService.hasSecret(ConfigKey.CLOUDFLARE_API_TOKEN)).thenReturn(true);
    assertThat(client.available()).isTrue();

    when(systemConfigService.getString(ConfigKey.CLOUDFLARE_ACCOUNT_ID)).thenReturn(" ");
    assertThat(client.available()).isFalse();

    when(systemConfigService.getString(ConfigKey.CLOUDFLARE_ACCOUNT_ID)).thenReturn(ACCOUNT_ID);
    when(systemConfigService.hasSecret(ConfigKey.CLOUDFLARE_API_TOKEN)).thenReturn(false);
    assertThat(client.available()).isFalse();

    // 모델이 비면 /ai/run/ 로 404 > 고르지 못하게
    when(systemConfigService.hasSecret(ConfigKey.CLOUDFLARE_API_TOKEN)).thenReturn(true);
    when(systemConfigService.getString(ConfigKey.CLOUDFLARE_IMAGE_MODEL)).thenReturn("");
    assertThat(client.available()).isFalse();
  }

  /// 테스트용 시계 (한도 소진 시각을 옮긴다)
  private static final class MutableClock extends Clock {

    private Instant now;

    MutableClock(Instant now) {
      this.now = now;
    }

    void set(Instant instant) {
      this.now = instant;
    }

    @Override
    public ZoneId getZone() {
      return ZoneOffset.UTC;
    }

    @Override
    public Clock withZone(ZoneId zone) {
      return this;
    }

    @Override
    public Instant instant() {
      return now;
    }
  }
}
