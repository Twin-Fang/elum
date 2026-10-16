package com.chuseok22.elumserver.ai.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.MultilingualPromptDefaults;
import com.chuseok22.elumserver.ai.core.PromptDefaults;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.ai.infrastructure.entity.PromptTemplate;
import com.chuseok22.elumserver.ai.infrastructure.repository.PromptTemplateRepository;
import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

class PromptTemplateSeederTest {

  private final PromptTemplateRepository repository = mock(PromptTemplateRepository.class);
  private final PromptTemplateSeeder seeder = new PromptTemplateSeeder(repository);

  @Test
  @DisplayName("ko 는 모든 키(9개)를 코드 기본값 그대로, locale=ko 로 넣는다")
  void ko_seedsEveryKeyVerbatim() {
    when(repository.findByPromptKeyAndLocale(any(), any())).thenReturn(Optional.empty());

    PromptTemplateSeeder.SeedResult result = seeder.seed(AppLocale.KO);

    assertThat(result).isEqualTo(new PromptTemplateSeeder.SeedResult(PromptKey.values().length, 0, 0));
    ArgumentCaptor<PromptTemplate> captor = ArgumentCaptor.forClass(PromptTemplate.class);
    verify(repository, times(PromptKey.values().length)).save(captor.capture());
    for (PromptTemplate saved : captor.getAllValues()) {
      assertThat(saved.getLocale()).isEqualTo("ko");
      assertThat(saved.getContent()).isEqualTo(PromptDefaults.DEFAULTS.get(saved.getPromptKey()));
    }
  }

  @Test
  @DisplayName("es 는 번역이 필요한 4개 키만 넣는다 — 그림 지시문 행은 만들지 않는다")
  void es_seedsOnlyLocalizedKeys() {
    when(repository.findByPromptKeyAndLocale(any(), any())).thenReturn(Optional.empty());

    PromptTemplateSeeder.SeedResult result = seeder.seed(AppLocale.ES);

    assertThat(result).isEqualTo(new PromptTemplateSeeder.SeedResult(4, 0, 0));
    ArgumentCaptor<PromptTemplate> captor = ArgumentCaptor.forClass(PromptTemplate.class);
    verify(repository, times(4)).save(captor.capture());
    assertThat(captor.getAllValues()).extracting(PromptTemplate::getPromptKey).containsExactlyInAnyOrder(
      PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, PromptKey.GEMINI_ROUTINE_QUESTION_PREFIX,
      PromptKey.FLUX_IMAGE_PROMPT_TRANSLATE, PromptKey.REALISTIC_IMAGE_PROMPT_TRANSLATE);
    for (PromptTemplate saved : captor.getAllValues()) {
      assertThat(saved.getLocale()).isEqualTo("es");
      assertThat(saved.getContent())
        .isEqualTo(MultilingualPromptDefaults.forLocale(saved.getPromptKey(), AppLocale.ES).orElseThrow());
    }
  }

  @Test
  @DisplayName("이미 있는 행은 건드리지 않는다 — 관리자가 다듬은 내용이 시딩으로 덮이지 않는다")
  void existingRowIsNeverOverwritten() {
    when(repository.findByPromptKeyAndLocale(any(), any())).thenReturn(Optional.empty());
    PromptTemplate existing = new PromptTemplate();
    existing.setPromptKey(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX);
    existing.setLocale("es");
    existing.setContent("손으로 다듬은 es");
    when(repository.findByPromptKeyAndLocale(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "es"))
      .thenReturn(Optional.of(existing));

    PromptTemplateSeeder.SeedResult result = seeder.seed(AppLocale.ES);

    assertThat(result).isEqualTo(new PromptTemplateSeeder.SeedResult(3, 1, 0));
    verify(repository, never()).save(argThat(t -> t.getPromptKey() == PromptKey.GEMINI_ROUTINE_CREATE_PREFIX));
    assertThat(existing.getContent()).isEqualTo("손으로 다듬은 es");
  }

  @Test
  @DisplayName("키 하나의 저장이 실패해도 나머지를 넣고 던지지 않는다 — 기동을 막지 않는다")
  void oneFailureDoesNotStopTheRest() {
    when(repository.findByPromptKeyAndLocale(any(), any())).thenReturn(Optional.empty());
    when(repository.save(argThat(t -> t != null && t.getPromptKey() == PromptKey.ROUTINE_IMAGE_PREFIX_EN)))
      .thenThrow(new RuntimeException("violates check constraint prompt_template_prompt_key_check"));

    PromptTemplateSeeder.SeedResult result = seeder.seed(AppLocale.KO);

    assertThat(result.failed()).isEqualTo(1);
    assertThat(result.created()).isEqualTo(PromptKey.values().length - 1);
  }

  @Test
  @DisplayName("ja·zh·en 도 각자 4개 — 언어 수만큼 같은 규칙이다")
  void otherLocalesSeedFourEach() {
    when(repository.findByPromptKeyAndLocale(any(), any())).thenReturn(Optional.empty());

    for (AppLocale locale : List.of(AppLocale.EN, AppLocale.JA, AppLocale.ZH)) {
      assertThat(seeder.seed(locale).created()).as(locale.name()).isEqualTo(4);
    }
  }
}
