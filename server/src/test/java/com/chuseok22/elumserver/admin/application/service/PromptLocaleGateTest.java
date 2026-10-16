package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.EnumSet;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 그 언어의 프롬프트 행이 모두 있어야 켤 수 있다. */
class PromptLocaleGateTest {

  private final PromptTemplateService promptTemplateService = mock(PromptTemplateService.class);
  private final PromptLocaleGate gate = new PromptLocaleGate(promptTemplateService);

  @Test
  @DisplayName("ko 만 켜는 것은 행을 보지도 않고 통과한다 — ko 행은 기동 때 시딩된다")
  void koOnly_passes() {
    assertThatCode(() -> gate.requireReady(EnumSet.of(AppLocale.KO))).doesNotThrowAnyException();
    verifyNoInteractions(promptTemplateService);
  }

  @Test
  @DisplayName("행이 모자란 언어가 하나라도 있으면 CONTENT_LOCALE_PROMPT_MISSING")
  void missingRows_throw() {
    when(promptTemplateService.missingKeys(AppLocale.ES)).thenReturn(List.of(PromptKey.FLUX_IMAGE_PROMPT_TRANSLATE));

    assertThatThrownBy(() -> gate.requireReady(EnumSet.of(AppLocale.KO, AppLocale.ES)))
      .isInstanceOfSatisfying(CustomException.class,
        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.CONTENT_LOCALE_PROMPT_MISSING));
  }

  @Test
  @DisplayName("행이 모두 있으면 통과한다")
  void completeRows_pass() {
    when(promptTemplateService.missingKeys(AppLocale.EN)).thenReturn(List.of());

    assertThatCode(() -> gate.requireReady(EnumSet.of(AppLocale.KO, AppLocale.EN))).doesNotThrowAnyException();
  }

  @Test
  @DisplayName("한 언어는 완성이어도 다른 언어가 모자라면 목록 전체를 거절한다")
  void oneIncompleteLocale_blocksTheWholeList() {
    when(promptTemplateService.missingKeys(AppLocale.EN)).thenReturn(List.of());
    when(promptTemplateService.missingKeys(AppLocale.JA)).thenReturn(List.of(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX));

    assertThatThrownBy(() -> gate.requireReady(EnumSet.of(AppLocale.KO, AppLocale.EN, AppLocale.JA)))
      .isInstanceOf(CustomException.class);
  }
}
