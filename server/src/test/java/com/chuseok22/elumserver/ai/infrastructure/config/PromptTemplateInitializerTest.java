package com.chuseok22.elumserver.ai.infrastructure.config;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.atLeast;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.PromptTemplateSeeder;
import com.chuseok22.elumserver.ai.core.PromptDefaults;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.ai.infrastructure.repository.PromptTemplateRepository;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class PromptTemplateInitializerTest {

  /**
   * 시딩 실패 격리: CHECK 제약(prompt_template_prompt_key_check)에 걸린 키가 있어도 기동은 계속
   */
  @Test
  @DisplayName("키 하나의 시딩이 실패해도 나머지를 넣고 기동을 막지 않는다")
  void oneKeyFails_othersStillSeeded() {
    PromptTemplateRepository repository = mock(PromptTemplateRepository.class);
    when(repository.findByPromptKeyAndLocale(any(), any())).thenReturn(Optional.empty());
    when(repository.save(argThat(t -> t != null && t.getPromptKey() == PromptKey.ROUTINE_IMAGE_PREFIX_EN)))
      .thenThrow(new RuntimeException("violates check constraint prompt_template_prompt_key_check"));

    assertThatCode(() -> new PromptTemplateInitializer(new PromptTemplateSeeder(repository)).run(null)).doesNotThrowAnyException();

    // 실패한 키를 빼고 나머지 기본값은 모두 저장을 시도했다.
    verify(repository, atLeast(PromptDefaults.DEFAULTS.size())).save(any(PromptTemplate.class));
  }

  @Test
  @DisplayName("기동 시딩은 ko 행만 만든다 — 다른 언어는 관리자가 만든다")
  void bootSeedsOnlyKo() {
    PromptTemplateRepository repository = mock(PromptTemplateRepository.class);
    when(repository.findByPromptKeyAndLocale(any(), any())).thenReturn(Optional.empty());

    new PromptTemplateInitializer(new PromptTemplateSeeder(repository)).run(null);

    verify(repository, atLeast(PromptDefaults.DEFAULTS.size()))
      .save(argThat(template -> template != null && "ko".equals(template.getLocale())));
    verify(repository, never()).save(argThat(template -> template != null && !"ko".equals(template.getLocale())));
  }
}
