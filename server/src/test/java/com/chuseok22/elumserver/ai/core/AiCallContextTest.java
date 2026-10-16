package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class AiCallContextTest {

  @AfterEach
  void tearDown() {
    AiCallContext.clear();
  }

  @Test
  @DisplayName("비어 있으면 KO — 컨텍스트를 세우지 않는 옛 경로가 지금 동작 그대로 돈다")
  void defaultsToKo() {
    assertThat(AiCallContext.currentContentLocale()).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("세운 언어가 읽히고 null 을 넣으면 비워진다")
  void setAndUnset() {
    AiCallContext.setContentLocale(AppLocale.ES);
    assertThat(AiCallContext.currentContentLocale()).isEqualTo(AppLocale.ES);

    AiCallContext.setContentLocale(null);
    assertThat(AiCallContext.currentContentLocale()).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("clear 는 회원·작업과 함께 언어도 비운다 — 풀의 스레드가 다음 요청에 언어를 새지 않는다")
  void clearRemovesLocale() {
    AiCallContext.setContentLocale(AppLocale.JA);
    AiCallContext.setMemberId("member-1");

    AiCallContext.clear();

    assertThat(AiCallContext.currentContentLocale()).isEqualTo(AppLocale.KO);
    assertThat(AiCallContext.currentMemberId()).isNull();
  }

  @Test
  @DisplayName("그림을 병렬로 그리는 자식 스레드가 부모의 언어를 물려받는다")
  void childThreadInheritsLocale() throws InterruptedException {
    AiCallContext.setContentLocale(AppLocale.ZH);
    AtomicReference<AppLocale> seen = new AtomicReference<>();

    Thread child = Thread.ofVirtual().start(() -> seen.set(AiCallContext.currentContentLocale()));
    child.join();

    assertThat(seen.get()).isEqualTo(AppLocale.ZH);
  }
}
