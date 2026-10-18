package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.request.PromptSampleRequest;
import com.chuseok22.elumserver.admin.application.dto.response.PromptTestResponse;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateSeeder;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextGenerationClient;
import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class AdminPromptServiceLocaleTest {

  @Mock private PromptTemplateService promptTemplateService;
  @Mock private PromptTemplateSeeder promptTemplateSeeder;
  @Mock private TextClientRouter textClientRouter;
  @Mock private TextGenerationClient textClient;

  @InjectMocks private AdminPromptService adminPromptService;

  @AfterEach
  void tearDown() {
    AiCallContext.clear();
  }

  @Test
  @DisplayName("언어를 받는 조회·수정·행 만들기·준비도는 서비스에 그 언어로 위임한다")
  void delegatesWithLocale() {
    adminPromptService.getAll(AppLocale.JA);
    adminPromptService.getTemplate(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, AppLocale.JA);
    adminPromptService.getHistory(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, AppLocale.JA);
    adminPromptService.update(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, AppLocale.JA, "내용", "kimchi");
    adminPromptService.seedLocale(AppLocale.JA);
    adminPromptService.missingKeys(AppLocale.JA);

    verify(promptTemplateService).getAll(AppLocale.JA);
    verify(promptTemplateService).getTemplate(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, AppLocale.JA);
    verify(promptTemplateService).getHistory(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, AppLocale.JA);
    verify(promptTemplateService).update(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, AppLocale.JA, "내용", "kimchi");
    verify(promptTemplateSeeder).seed(AppLocale.JA);
    verify(promptTemplateService).missingKeys(AppLocale.JA);
  }

  @Test
  @DisplayName("기존 인자 없는 형태는 ko 로 위임한다 — 지금 호출부가 그대로 동작한다")
  void legacyOverloadsAreKo() {
    adminPromptService.getAll();
    adminPromptService.update(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "내용");

    verify(promptTemplateService).getAll();
    verify(promptTemplateService).update(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "내용");
  }

  @Test
  @DisplayName("언어를 고른 시험은 그 언어의 스키마로 AI 를 부르고 끝나면 언어를 비운다 — 가짜 클라이언트로 본다")
  void test_runsWithTheChosenLocale_thenClears() {
    when(textClientRouter.current()).thenReturn(textClient);
    AtomicReference<AppLocale> seen = new AtomicReference<>();
    when(textClient.generateRoutineJsonForTest(any(), any())).thenAnswer(invocation -> {
      seen.set(AiCallContext.currentContentLocale());
      return "{\"title\":\"Ir al colegio\",\"steps\":[{\"order\":1,\"title\":\"Ponte la ropa\",\"description\":\"Ponte la ropa\"}]}";
    });

    PromptTestResponse response = adminPromptService.test(
      PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, AppLocale.ES, "instruction", "Ir al colegio", null);

    assertThat(response.result()).isNotNull();
    assertThat(seen.get()).isEqualTo(AppLocale.ES);
    assertThat(AiCallContext.currentContentLocale()).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("PromptSampleRequest 의 locale 은 비었거나 모르는 값이면 ko 다")
  void sampleRequestLocale() {
    assertThat(new PromptSampleRequest("c", "s", null, "es").localeOrKo()).isEqualTo(AppLocale.ES);
    assertThat(new PromptSampleRequest("c", "s", null, null).localeOrKo()).isEqualTo(AppLocale.KO);
    assertThat(new PromptSampleRequest("c", "s", null, "xx").localeOrKo()).isEqualTo(AppLocale.KO);
  }
}
