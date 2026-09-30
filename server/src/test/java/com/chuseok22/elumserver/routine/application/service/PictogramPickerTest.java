package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.PictogramCatalog;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextGenerationClient;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 카드 직접 추가 시 픽토그램 고르기 (#247). 실제 AI 는 부르지 않는다 — 텍스트 클라이언트를 가짜로 둔다.
 * 핵심 약속은 "어떤 실패도 카드 추가를 막지 않고 폴백 id 를 돌려준다" 이다.
 */
class PictogramPickerTest {

  private static final String FALLBACK = "go_,_to";

  private final PictogramCatalog catalog =
    new PictogramCatalog(List.of("brush_teeth", "get_dressed_,_to", FALLBACK), FALLBACK);
  private TextClientRouter router;
  private TextGenerationClient client;
  private AiDailyBudgetGuard budgetGuard;
  private PictogramPicker picker;

  @BeforeEach
  void setUp() {
    router = mock(TextClientRouter.class);
    client = mock(TextGenerationClient.class);
    budgetGuard = mock(AiDailyBudgetGuard.class);
    when(router.current()).thenReturn(client);
    picker = new PictogramPicker(catalog, router, budgetGuard, Duration.ofMillis(300));
  }

  @Test
  @DisplayName("모델이 카탈로그의 id 를 고르면 그대로 쓴다")
  void validId_isReturned() {
    when(client.pickPictogramJson("양치해요", "이를 닦아요")).thenReturn("{\"pictogramId\":\"brush_teeth\"}");

    assertThat(picker.pick("member-1", "양치해요", "이를 닦아요")).isEqualTo("brush_teeth");
  }

  @Test
  @DisplayName("설명이 빈 카드도 제목만으로 고른다")
  void blankDescription_stillPicks() {
    when(client.pickPictogramJson("양치해요", "")).thenReturn("{\"pictogramId\":\"brush_teeth\"}");

    assertThat(picker.pick("member-1", "양치해요", "")).isEqualTo("brush_teeth");
  }

  @Test
  @DisplayName("모델이 null 을 주면(알맞은 그림 없음) 폴백 id 를 저장한다")
  void nullId_fallsBack() {
    when(client.pickPictogramJson(any(), any())).thenReturn("{\"pictogramId\":null}");

    assertThat(picker.pick("member-1", "제목", "")).isEqualTo(FALLBACK);
  }

  @Test
  @DisplayName("카탈로그에 없는 id(환각)는 그대로 저장하지 않고 폴백으로 바꾼다")
  void invalidId_fallsBack() {
    when(client.pickPictogramJson(any(), any())).thenReturn("{\"pictogramId\":\"teleport_to_moon\"}");

    assertThat(picker.pick("member-1", "제목", "")).isEqualTo(FALLBACK);
  }

  @Test
  @DisplayName("필드가 빠지거나 JSON 이 깨진 응답도 폴백 — 카드 추가는 실패하지 않는다")
  void malformedResponse_fallsBack() {
    when(client.pickPictogramJson(any(), any())).thenReturn("{}", "이건 JSON 이 아니다", "{\"pictogramId\":123}");

    assertThat(picker.pick("m", "t", "")).isEqualTo(FALLBACK);
    assertThat(picker.pick("m", "t", "")).isEqualTo(FALLBACK);
    assertThat(picker.pick("m", "t", "")).isEqualTo(FALLBACK);
  }

  @Test
  @DisplayName("호출이 예외로 실패해도 폴백을 돌려주고 던지지 않는다")
  void callFailure_fallsBack() {
    when(client.pickPictogramJson(any(), any())).thenThrow(new IllegalStateException("OpenAI 500"));

    assertThat(picker.pick("member-1", "제목", "")).isEqualTo(FALLBACK);
  }

  @Test
  @DisplayName("텍스트 제공자를 쓸 수 없어도(키 없음) 폴백 — 카드 추가는 성공한다")
  void providerUnavailable_fallsBack() {
    when(router.current()).thenThrow(new CustomException(ErrorCode.TEXT_PROVIDER_UNAVAILABLE));

    assertThat(picker.pick("member-1", "제목", "")).isEqualTo(FALLBACK);
  }

  @Test
  @DisplayName("제한 시간을 넘기면 기다리지 않고 폴백을 돌려준다")
  void timeout_fallsBack() {
    when(client.pickPictogramJson(any(), any())).thenAnswer(invocation -> {
      Thread.sleep(3_000);
      return "{\"pictogramId\":\"brush_teeth\"}";
    });

    long startedAt = System.currentTimeMillis();
    String picked = picker.pick("member-1", "제목", "");

    assertThat(picked).isEqualTo(FALLBACK);
    assertThat(System.currentTimeMillis() - startedAt).isLessThan(2_000);
  }

  @Test
  @DisplayName("하루 비용 상한에 걸리면 AI 를 부르지 않고 폴백을 쓴다")
  void budgetReached_skipsCall() {
    when(budgetGuard.isReached()).thenReturn(true);

    assertThat(picker.pick("member-1", "제목", "")).isEqualTo(FALLBACK);
    verifyNoInteractions(client);
    verify(router, never()).current();
  }

  @Test
  @DisplayName("카탈로그를 못 읽은 서버는 AI 를 부르지 않고 null 이다")
  void emptyCatalog_returnsNull() {
    PictogramPicker emptyPicker = new PictogramPicker(PictogramCatalog.empty(), router, budgetGuard, Duration.ofMillis(300));

    assertThat(emptyPicker.pick("member-1", "제목", "")).isNull();
    verifyNoInteractions(router);
  }

  @Test
  @DisplayName("호출 스레드에 회원 맥락을 세워 호출 기록에 회원이 남고, 끝나면 비운다")
  void setsMemberContextForCallLog() {
    AtomicReference<String> seen = new AtomicReference<>();
    when(client.pickPictogramJson(any(), any())).thenAnswer(invocation -> {
      seen.set(AiCallContext.currentMemberId());
      return "{\"pictogramId\":\"brush_teeth\"}";
    });

    picker.pick("member-42", "제목", "");

    assertThat(seen.get()).isEqualTo("member-42");
    assertThat(AiCallContext.currentMemberId()).isNull();
  }
}
