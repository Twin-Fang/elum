package com.chuseok22.elumserver.ai.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.ai.infrastructure.repository.PromptTemplateRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class PromptTemplateServiceTest {

  @Mock
  private PromptTemplateRepository promptTemplateRepository;

  @InjectMocks
  private PromptTemplateService promptTemplateService;

  @Test
  @DisplayName("getContent는 저장된 프롬프트 내용을 반환한다")
  void getContent_existingKey_returnsContent() {
    PromptTemplate template = new PromptTemplate();
    template.setPromptKey(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX);
    template.setContent("텍스트 생성 프롬프트");
    when(promptTemplateRepository.findByPromptKey(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX))
      .thenReturn(Optional.of(template));

    String content = promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX);

    assertThat(content).isEqualTo("텍스트 생성 프롬프트");
  }

  @Test
  @DisplayName("getContent는 저장된 키가 없으면 PROMPT_TEMPLATE_NOT_FOUND를 던진다")
  void getContent_missingKey_throwsCustomException() {
    when(promptTemplateRepository.findByPromptKey(PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX))
      .thenReturn(Optional.empty());

    assertThatThrownBy(() -> promptTemplateService.getContent(PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode())
        .isEqualTo(ErrorCode.PROMPT_TEMPLATE_NOT_FOUND));
  }

  @Test
  @DisplayName("update는 저장된 프롬프트의 내용을 변경한다")
  void update_existingKey_changesContent() {
    PromptTemplate template = new PromptTemplate();
    template.setPromptKey(PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK);
    template.setContent("이전 내용");
    when(promptTemplateRepository.findByPromptKey(PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK))
      .thenReturn(Optional.of(template));

    promptTemplateService.update(PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK, "새 내용");

    assertThat(template.getContent()).isEqualTo("새 내용");
  }

  @Test
  @DisplayName("getAll은 PromptKey 선언 순서대로 정렬해서 반환한다")
  void getAll_returnsSortedByDeclarationOrder() {
    PromptTemplate image = new PromptTemplate();
    image.setPromptKey(PromptKey.GEMINI_ROUTINE_IMAGE_PREFIX);
    PromptTemplate localLlm = new PromptTemplate();
    localLlm.setPromptKey(PromptKey.LOCAL_LLM_SENSITIVE_INFO_CHECK);
    when(promptTemplateRepository.findAll()).thenReturn(List.of(image, localLlm));

    List<PromptTemplate> result = promptTemplateService.getAll();

    assertThat(result).containsExactly(localLlm, image);
  }
}
