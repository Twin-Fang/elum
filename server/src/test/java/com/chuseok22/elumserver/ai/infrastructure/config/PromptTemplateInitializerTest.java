package com.chuseok22.elumserver.ai.infrastructure.config;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.atLeast;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.PromptDefaults;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.ai.infrastructure.repository.PromptTemplateRepository;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class PromptTemplateInitializerTest {

  /**
   * ddl-auto 로 만든 prompt_template 에는 Hibernate 가 그때의 키 목록으로 CHECK 제약을 건다
   * (로컬 DB 에서 확인: prompt_template_prompt_key_check). 새 키를 넣으면 그 제약에 걸려
   * 저장이 실패하는데, 예전에는 그 예외가 ApplicationRunner 밖으로 나가 <b>서버가 뜨지 않았다</b>.
   * 새 키 하나 때문에 이미 돌던 기능까지 멈추면 안 된다 (#375).
   */
  @Test
  @DisplayName("키 하나의 시딩이 실패해도 나머지를 넣고 기동을 막지 않는다")
  void oneKeyFails_othersStillSeeded() {
    PromptTemplateRepository repository = mock(PromptTemplateRepository.class);
    when(repository.findByPromptKey(any())).thenReturn(Optional.empty());
    when(repository.save(argThat(t -> t != null && t.getPromptKey() == PromptKey.ROUTINE_IMAGE_PREFIX_EN)))
      .thenThrow(new RuntimeException("violates check constraint prompt_template_prompt_key_check"));

    assertThatCode(() -> new PromptTemplateInitializer(repository).run(null)).doesNotThrowAnyException();

    // 실패한 키를 빼고 나머지 기본값은 모두 저장을 시도했다.
    verify(repository, atLeast(PromptDefaults.DEFAULTS.size())).save(any(PromptTemplate.class));
  }
}
