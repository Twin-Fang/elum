package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextGenerationClient;
import com.chuseok22.elumserver.common.locale.AppLocale;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 카드 직접 추가의 픽토그램 고르기가 일과 언어로 돈다. 실제 AI 는 부르지 않는다. */
class PictogramPickerLocaleTest {

  private static final String FALLBACK = "go_,_to";

  private TextGenerationClient client;
  private PictogramPicker picker;

  @BeforeEach
  void setUp() {
    TextClientRouter router = mock(TextClientRouter.class);
    client = mock(TextGenerationClient.class);
    when(router.current()).thenReturn(client);
    picker = new PictogramPicker(
      new PictogramCatalog(List.of("brush_teeth", FALLBACK), FALLBACK), router,
      mock(AiDailyBudgetGuard.class), Duration.ofMillis(300));
  }

  @AfterEach
  void tearDown() {
    AiCallContext.clear();
  }

  @Test
  @DisplayName("호출 스레드의 일과 언어가 가상 스레드의 픽토그램 호출까지 간다")
  void localeReachesTheModelCall() {
    AiCallContext.setContentLocale(AppLocale.ES);
    AtomicReference<AppLocale> seen = new AtomicReference<>();
    when(client.pickPictogramJson(any(), any())).thenAnswer(invocation -> {
      seen.set(AiCallContext.currentContentLocale());
      return "{\"pictogramId\":\"brush_teeth\"}";
    });

    assertThat(picker.pick("member-1", "Lávate los dientes", "")).isEqualTo("brush_teeth");

    assertThat(seen.get()).isEqualTo(AppLocale.ES);
    // 호출한 쪽 스레드의 언어는 건드리지 않는다
    assertThat(AiCallContext.currentContentLocale()).isEqualTo(AppLocale.ES);
  }

  @Test
  @DisplayName("언어를 세우지 않으면 ko 다 — 지금 동작 그대로")
  void defaultsToKo() {
    AtomicReference<AppLocale> seen = new AtomicReference<>();
    when(client.pickPictogramJson(any(), any())).thenAnswer(invocation -> {
      seen.set(AiCallContext.currentContentLocale());
      return "{\"pictogramId\":\"brush_teeth\"}";
    });

    picker.pick("member-1", "양치해요", "");

    assertThat(seen.get()).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("es 일과에서 AI 가 실패해도 폴백 id 다 — 카드 추가는 성공한다 (서비스 원칙 6)")
  void failureStillFallsBack() {
    AiCallContext.setContentLocale(AppLocale.ES);
    when(client.pickPictogramJson(any(), any())).thenThrow(new IllegalStateException("AI down"));

    assertThat(picker.pick("member-1", "Lávate los dientes", "")).isEqualTo(FALLBACK);
  }
}
