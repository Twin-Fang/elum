package com.chuseok22.elumserver.ai.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.core.SensitiveInfoCheckResult;
import com.chuseok22.elumserver.ai.infrastructure.client.LocalLlmChatResponse;
import com.chuseok22.elumserver.ai.infrastructure.client.LocalLlmClient;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.infrastructure.properties.LocalLlmProperties;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class SensitiveInfoGuardServiceTest {

  @Mock
  private LocalLlmProperties localLlmProperties;

  @Mock
  private LocalLlmClient localLlmClient;

  @Mock
  private PromptTemplateService promptTemplateService;

  @InjectMocks
  private SensitiveInfoGuardService sensitiveInfoGuardService;

  @Test
  @DisplayName("enabled=false면 로컬 LLM을 호출하지 않고 원문을 그대로 통과시킨다")
  void check_disabled_passesThroughOriginalText() {
    when(localLlmProperties.enabled()).thenReturn(false);

    SensitiveInfoCheckResult result = sensitiveInfoGuardService.check("010-1234-5678로 연락주세요");

    assertThat(result.checked()).isFalse();
    assertThat(result.hasSensitiveInfo()).isFalse();
    assertThat(result.sanitizedText()).isEqualTo("010-1234-5678로 연락주세요");
  }

  @Test
  @DisplayName("로컬 LLM이 정상 응답하면 마스킹된 텍스트를 반환한다")
  void check_success_returnsSanitizedText() {
    when(localLlmProperties.enabled()).thenReturn(true);
    when(localLlmProperties.model()).thenReturn("test-model");
    when(promptTemplateService.getContent(PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK)).thenReturn("system prompt");
    String responseJson =
      "{\"hasSensitiveInfo\":true,\"categories\":[\"전화번호\"],\"reason\":\"전화번호 포함\","
        + "\"sanitizedText\":\"<전화번호>로 연락주세요\"}";
    when(localLlmClient.chat(any())).thenReturn(new LocalLlmChatResponse(responseJson, "test-model", true));

    SensitiveInfoCheckResult result = sensitiveInfoGuardService.check("010-1234-5678로 연락주세요");

    assertThat(result.checked()).isTrue();
    assertThat(result.hasSensitiveInfo()).isTrue();
    assertThat(result.sanitizedText()).isEqualTo("<전화번호>로 연락주세요");
  }

  @Test
  @DisplayName("로컬 LLM 응답이 스키마를 따르지 않으면 fail-open으로 원문을 통과시킨다")
  void check_invalidSchema_failsOpenWithOriginalText() {
    when(localLlmProperties.enabled()).thenReturn(true);
    when(localLlmProperties.model()).thenReturn("test-model");
    when(promptTemplateService.getContent(PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK)).thenReturn("system prompt");
    String invalidJson = "{\"hasSensitiveInfo\":true}";
    when(localLlmClient.chat(any())).thenReturn(new LocalLlmChatResponse(invalidJson, "test-model", true));

    SensitiveInfoCheckResult result = sensitiveInfoGuardService.check("010-1234-5678로 연락주세요");

    assertThat(result.checked()).isFalse();
    assertThat(result.sanitizedText()).isEqualTo("010-1234-5678로 연락주세요");
  }

  @Test
  @DisplayName("checkForTest는 실패 시 fail-open 없이 PROMPT_TEST_LOCAL_LLM_FAILED를 던진다")
  void checkForTest_failure_throwsCustomException() {
    when(localLlmClient.chat(any())).thenReturn(new LocalLlmChatResponse(null, "test-model", false));

    assertThatThrownBy(() -> sensitiveInfoGuardService.checkForTest("system prompt", "010-1234-5678"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.PROMPT_TEST_LOCAL_LLM_FAILED));
  }
}
