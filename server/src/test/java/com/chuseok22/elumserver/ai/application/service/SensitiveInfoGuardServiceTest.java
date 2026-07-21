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
    String responseJson = "{\"detections\":[{\"category\":\"전화번호\",\"matchedText\":\"010-1234-5678\"}]}";
    when(localLlmClient.chat(any())).thenReturn(new LocalLlmChatResponse(responseJson, "test-model", true));

    SensitiveInfoCheckResult result = sensitiveInfoGuardService.check("010-1234-5678로 연락주세요");

    assertThat(result.checked()).isTrue();
    assertThat(result.hasSensitiveInfo()).isTrue();
    assertThat(result.categories()).containsExactly("전화번호");
    assertThat(result.sanitizedText()).isEqualTo("<전화번호>로 연락주세요");
  }

  @Test
  @DisplayName("여러 카테고리가 탐지되면 categories에 중복 없이 전부 담기고 전부 마스킹된다")
  void check_multipleCategories_masksAllAndListsAllCategories() {
    when(localLlmProperties.enabled()).thenReturn(true);
    when(localLlmProperties.model()).thenReturn("test-model");
    when(promptTemplateService.getContent(PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK)).thenReturn("system prompt");
    String responseJson = "{\"detections\":["
      + "{\"category\":\"이름\",\"matchedText\":\"김하늘\"},"
      + "{\"category\":\"주소\",\"matchedText\":\"서울시 송파구 방이동\"}"
      + "]}";
    when(localLlmClient.chat(any())).thenReturn(new LocalLlmChatResponse(responseJson, "test-model", true));

    SensitiveInfoCheckResult result =
      sensitiveInfoGuardService.check("김하늘이는 서울시 송파구 방이동에 살아요.");

    assertThat(result.categories()).containsExactlyInAnyOrder("이름", "주소");
    assertThat(result.sanitizedText()).isEqualTo("<이름>이는 <주소>에 살아요.");
  }

  @Test
  @DisplayName("같은 값이 문장에 두 번 등장하면 전부 마스킹한다")
  void check_repeatedMatchedText_masksAllOccurrences() {
    when(localLlmProperties.enabled()).thenReturn(true);
    when(localLlmProperties.model()).thenReturn("test-model");
    when(promptTemplateService.getContent(PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK)).thenReturn("system prompt");
    String responseJson = "{\"detections\":["
      + "{\"category\":\"이름\",\"matchedText\":\"김하늘\"},"
      + "{\"category\":\"이름\",\"matchedText\":\"김하늘\"}"
      + "]}";
    when(localLlmClient.chat(any())).thenReturn(new LocalLlmChatResponse(responseJson, "test-model", true));

    SensitiveInfoCheckResult result =
      sensitiveInfoGuardService.check("김하늘이 신청했고 김하늘에게 다시 연락했습니다.");

    assertThat(result.sanitizedText()).isEqualTo("<이름>이 신청했고 <이름>에게 다시 연락했습니다.");
  }

  @Test
  @DisplayName("matchedText가 원문에 없으면 그 항목만 건너뛰고 나머지는 정상 마스킹한다")
  void check_matchedTextNotInOriginalText_skipsOnlyThatDetection() {
    when(localLlmProperties.enabled()).thenReturn(true);
    when(localLlmProperties.model()).thenReturn("test-model");
    when(promptTemplateService.getContent(PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK)).thenReturn("system prompt");
    String responseJson = "{\"detections\":["
      + "{\"category\":\"이름\",\"matchedText\":\"이서준\"},"
      + "{\"category\":\"이메일\",\"matchedText\":\"ABC@test.com\"}"
      + "]}";
    when(localLlmClient.chat(any())).thenReturn(new LocalLlmChatResponse(responseJson, "test-model", true));

    SensitiveInfoCheckResult result =
      sensitiveInfoGuardService.check("이서준이 이메일은 abc@test.com입니다.");

    assertThat(result.hasSensitiveInfo()).isTrue();
    assertThat(result.categories()).containsExactlyInAnyOrder("이름", "이메일");
    assertThat(result.sanitizedText()).isEqualTo("<이름>이 이메일은 abc@test.com입니다.");
  }

  @Test
  @DisplayName("detections가 빈 배열이면 민감정보 없음으로 처리한다")
  void check_emptyDetections_returnsNoSensitiveInfo() {
    when(localLlmProperties.enabled()).thenReturn(true);
    when(localLlmProperties.model()).thenReturn("test-model");
    when(promptTemplateService.getContent(PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK)).thenReturn("system prompt");
    String responseJson = "{\"detections\":[]}";
    when(localLlmClient.chat(any())).thenReturn(new LocalLlmChatResponse(responseJson, "test-model", true));

    SensitiveInfoCheckResult result = sensitiveInfoGuardService.check("내일 비가 많이 올 예정이야.");

    assertThat(result.hasSensitiveInfo()).isFalse();
    assertThat(result.checked()).isTrue();
    assertThat(result.categories()).isEmpty();
    assertThat(result.sanitizedText()).isEqualTo("내일 비가 많이 올 예정이야.");
  }

  @Test
  @DisplayName("로컬 LLM 응답에 detections 필드 자체가 없으면 fail-open으로 원문을 통과시킨다")
  void check_missingDetectionsField_failsOpenWithOriginalText() {
    when(localLlmProperties.enabled()).thenReturn(true);
    when(localLlmProperties.model()).thenReturn("test-model");
    when(promptTemplateService.getContent(PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK)).thenReturn("system prompt");
    String invalidJson = "{}";
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
