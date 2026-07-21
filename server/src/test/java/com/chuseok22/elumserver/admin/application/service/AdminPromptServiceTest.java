package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.PromptTemplateService;
import com.chuseok22.elumserver.ai.application.service.SensitiveInfoGuardService;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiRoutineImagePromptBuilder;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.chuseok22.elumserver.admin.application.dto.request.PromptSampleRequest;
import com.chuseok22.elumserver.admin.application.dto.response.PromptTestResponse;
import com.chuseok22.elumserver.ai.core.RoutineStepDraft;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiGenerateContentResponse;
import java.util.List;

@ExtendWith(MockitoExtension.class)
class AdminPromptServiceTest {

  @Mock
  private PromptTemplateService promptTemplateService;

  @Mock
  private SensitiveInfoGuardService sensitiveInfoGuardService;

  @Mock
  private GeminiTextClient geminiTextClient;

  @Mock
  private GeminiImageClient geminiImageClient;

  @Mock
  private GeminiRoutineImagePromptBuilder imagePromptBuilder;

  @InjectMocks
  private AdminPromptService adminPromptService;

  @Test
  @DisplayName("GEMINI_ROUTINE_CREATE_PREFIX preview는 GeminiTextClient의 실제 조립 메서드를 그대로 사용한다")
  void preview_createPrefix_delegatesToGeminiTextClientBuilder() {
    when(geminiTextClient.buildCreateRoutineUserContent("일과 원문", null, java.util.Set.of(), java.util.List.of()))
      .thenReturn("{\"task\":\"CREATE_ROUTINE\"}");

    String result = adminPromptService.preview(
      PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "시스템 프롬프트", "일과 원문", null, null, null
    );

    assertThat(result).contains("[System]\n시스템 프롬프트");
    assertThat(result).contains("{\"task\":\"CREATE_ROUTINE\"}");
    assertThat(result).doesNotContain("<text>");
  }

  @Test
  @DisplayName("GEMINI_ROUTINE_IMAGE_PREFIX preview는 GeminiRoutineImagePromptBuilder를 그대로 사용한다")
  void preview_imagePrefix_delegatesToImagePromptBuilder() {
    when(imagePromptBuilder.build("이미지 프롬프트", "옷을 입어요", CharacterType.LULU))
      .thenReturn("이미지 프롬프트\n\n장면 정보:\n{...}");

    String result = adminPromptService.preview(
      PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX, "이미지 프롬프트", "옷을 입어요", CharacterType.LULU, null, null
    );

    assertThat(result).isEqualTo("이미지 프롬프트\n\n장면 정보:\n{...}");
  }

  @Test
  @DisplayName("LOCAL_LLM_SENSITIVE_INFO_CHECK preview는 <text> 태그가 아니라 SensitiveInfoGuardService의 JSON 래핑을 사용한다")
  void preview_localLlmPrefix_usesJsonWrappingNotTextTag() {
    when(sensitiveInfoGuardService.buildUserContent("김민준입니다")).thenReturn("{\"text\":\"김민준입니다\"}");

    String result = adminPromptService.preview(
      PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK, "시스템 프롬프트", "김민준입니다", null, null, null
    );

    assertThat(result).contains("{\"text\":\"김민준입니다\"}");
    assertThat(result).doesNotContain("<text>");
  }

  @Test
  @DisplayName("GEMINI_ROUTINE_REVISE_PREFIX preview는 previousTitle/previousSteps에 order 1부터 부여해 전달한다")
  void preview_revisePrefix_passesPreviousRoutineFieldsWithAssignedOrder() {
    List<PromptSampleRequest.PreviousStepInput> previousSteps = List.of(
      new PromptSampleRequest.PreviousStepInput("일어나기", "침대에서 일어나요."),
      new PromptSampleRequest.PreviousStepInput("옷 입기", "옷을 입어요.")
    );
    List<RoutineStepDraft.StepDraft> expectedStepDrafts = List.of(
      new RoutineStepDraft.StepDraft(1, "일어나기", "침대에서 일어나요."),
      new RoutineStepDraft.StepDraft(2, "옷 입기", "옷을 입어요.")
    );
    when(geminiTextClient.buildReviseRoutineUserContent(
      "학교에 갈 준비를 해요", expectedStepDrafts, "가방을 챙기는 단계를 추가해줘요", null, java.util.Set.of()
    )).thenReturn("{\"task\":\"REVISE_ROUTINE\"}");

    String result = adminPromptService.preview(
      PromptKey.GEMINI_ROUTINE_REVISE_PREFIX, "시스템 프롬프트", "가방을 챙기는 단계를 추가해줘요", null,
      "학교에 갈 준비를 해요", previousSteps
    );

    assertThat(result).contains("{\"task\":\"REVISE_ROUTINE\"}");
  }

  @Test
  @DisplayName("previousTitle/previousSteps가 null이면 빈 문자열/빈 목록으로 전달한다")
  void preview_revisePrefix_nullPreviousRoutine_passesEmptyDefaults() {
    when(geminiTextClient.buildReviseRoutineUserContent(
      "", List.of(), "피드백", null, java.util.Set.of()
    )).thenReturn("{}");

    String result = adminPromptService.preview(
      PromptKey.GEMINI_ROUTINE_REVISE_PREFIX, "시스템 프롬프트", "피드백", null, null, null
    );

    assertThat(result).contains("{}");
  }

  @Test
  @DisplayName("GEMINI_ROUTINE_REVISE_PREFIX test는 previousTitle/previousSteps를 reviseForTest에 그대로 전달한다")
  void test_revisePrefix_passesPreviousRoutineFieldsToReviseForTest() {
    List<PromptSampleRequest.PreviousStepInput> previousSteps = List.of(
      new PromptSampleRequest.PreviousStepInput("일어나기", "침대에서 일어나요.")
    );
    List<RoutineStepDraft.StepDraft> expectedStepDrafts = List.of(
      new RoutineStepDraft.StepDraft(1, "일어나기", "침대에서 일어나요.")
    );
    GeminiGenerateContentResponse fakeResponse = new GeminiGenerateContentResponse(
      List.of(new GeminiGenerateContentResponse.Candidate(
        new GeminiGenerateContentResponse.Content(
          List.of(new GeminiGenerateContentResponse.Part(
            "{\"title\":\"학교에 갈 준비를 해요\",\"steps\":"
              + "[{\"order\":1,\"title\":\"일어나기\",\"description\":\"침대에서 일어나요.\"}]}",
            null
          ))
        )
      ))
    );
    when(geminiTextClient.reviseForTest(
      "시스템 프롬프트", "학교에 갈 준비를 해요", expectedStepDrafts, "가방을 챙기는 단계를 추가해줘요"
    )).thenReturn(fakeResponse);

    PromptTestResponse response = adminPromptService.test(
      PromptKey.GEMINI_ROUTINE_REVISE_PREFIX, "시스템 프롬프트", "가방을 챙기는 단계를 추가해줘요", null,
      "학교에 갈 준비를 해요", previousSteps
    );

    assertThat(response.result()).isNotNull();
  }
}
