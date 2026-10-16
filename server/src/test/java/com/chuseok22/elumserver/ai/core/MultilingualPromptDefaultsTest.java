package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.Optional;
import java.util.regex.Pattern;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

class MultilingualPromptDefaultsTest {

  private static final Pattern HANGUL = Pattern.compile("[\\uAC00-\\uD7A3\\u3131-\\u318E]");
  // 사용자를 아이로 부르지 않는다(이슈 #197). childProfile 같은 필드 이름은 단어 경계라 걸리지 않는다.
  private static final Pattern CHILD_WORDS = Pattern.compile("(?i)\\b(child|children|kid|kids|boy|girl)\\b");

  @Test
  @DisplayName("ko 는 코드 기본값 그대로다 — 한 글자도 바꾸지 않는다")
  void ko_isTheCurrentDefaultVerbatim() {
    assertThat(PromptDefaults.DEFAULTS.keySet()).containsExactlyInAnyOrder(PromptKey.values());
    for (PromptKey key : PromptKey.values()) {
      assertThat(MultilingualPromptDefaults.forLocale(key, AppLocale.KO))
        .as(key.name())
        .isEqualTo(Optional.of(PromptDefaults.DEFAULTS.get(key)));
    }
  }

  @ParameterizedTest
  @EnumSource(value = AppLocale.class, names = "KO", mode = EnumSource.Mode.EXCLUDE)
  @DisplayName("언어 중립 키는 ko 가 아닌 언어에 행이 없고, 번역이 필요한 키는 모두 있다")
  void nonKo_rowsExistOnlyForLocalizedKeys(AppLocale locale) {
    for (PromptKey key : PromptKey.values()) {
      assertThat(MultilingualPromptDefaults.forLocale(key, locale).isPresent())
        .as("%s / %s", key, locale)
        .isEqualTo(key.isLocalized());
    }
  }

  @ParameterizedTest
  @EnumSource(value = AppLocale.class, names = "KO", mode = EnumSource.Mode.EXCLUDE)
  @DisplayName("일과 생성 지시문은 빈칸 없이 펼쳐지고 출력 언어·자리표시·어조·길이 규칙이 들어 있다")
  void createPrompt_isFullyExpanded(AppLocale locale) {
    ContentLanguageSpec spec = ContentLanguageSpec.of(locale);
    String prompt = MultilingualPromptDefaults.forLocale(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, locale).orElseThrow();

    assertThat(prompt).doesNotContain("{").doesNotContain("}");
    assertThat(prompt).contains(spec.englishName());
    assertThat(prompt).contains(NicknamePlaceholder.placeholderFor(locale));
    assertThat(prompt).contains(spec.toneGuide()).contains(spec.stepTitleLength()).contains(spec.descriptionLength());
    assertThat(prompt).contains("routineText").contains("additionalAnswers").contains("supportGoals");
    assertThat(prompt).contains("Never include diagnoses");
    assertThat(prompt).contains("JSON Schema");
    assertThat(HANGUL.matcher(prompt).find()).as("한글이 섞이면 안 된다").isFalse();
  }

  @ParameterizedTest
  @EnumSource(value = AppLocale.class, names = "KO", mode = EnumSource.Mode.EXCLUDE)
  @DisplayName("질문 지시문은 질문·선택지 출력 언어와 직접 입력 금지, 개수 규칙을 담는다")
  void questionPrompt_isFullyExpanded(AppLocale locale) {
    ContentLanguageSpec spec = ContentLanguageSpec.of(locale);
    String prompt = MultilingualPromptDefaults.forLocale(PromptKey.GEMINI_ROUTINE_QUESTION_PREFIX, locale).orElseThrow();

    assertThat(prompt).doesNotContain("{").doesNotContain("}");
    assertThat(prompt).contains(spec.englishName()).contains(spec.questionExamples());
    assertThat(prompt).contains("supportGoal").contains("\"other\"").contains("exactly 2 items");
    assertThat(HANGUL.matcher(prompt).find()).isFalse();
  }

  @ParameterizedTest
  @EnumSource(value = AppLocale.class, names = "KO", mode = EnumSource.Mode.EXCLUDE)
  @DisplayName("지시문은 사용자를 아이·아동으로 부르라고 하지 않는다 (이슈 #197, 서비스 원칙)")
  void prompts_doNotAddressUserAsChild(AppLocale locale) {
    for (PromptKey key : new PromptKey[]{PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, PromptKey.GEMINI_ROUTINE_QUESTION_PREFIX}) {
      String prompt = MultilingualPromptDefaults.forLocale(key, locale).orElseThrow();
      assertThat(CHILD_WORDS.matcher(prompt).find()).as("%s / %s", key, locale).isFalse();
    }
  }

  @ParameterizedTest
  @EnumSource(value = AppLocale.class, names = "KO", mode = EnumSource.Mode.EXCLUDE)
  @DisplayName("그림 문장 번역 지시문은 'Korean step sentence' 를 일과 언어 이름으로 바꾼다 — 나머지 규칙은 ko 와 같다")
  void translatePrompts_nameTheSourceLanguage(AppLocale locale) {
    String name = ContentLanguageSpec.of(locale).englishName();
    for (PromptKey key : new PromptKey[]{PromptKey.FLUX_IMAGE_PROMPT_TRANSLATE, PromptKey.REALISTIC_IMAGE_PROMPT_TRANSLATE}) {
      String prompt = MultilingualPromptDefaults.forLocale(key, locale).orElseThrow();
      assertThat(prompt).contains(name + " step sentence").doesNotContain("Korean");
      assertThat(prompt).isEqualTo(PromptDefaults.DEFAULTS.get(key).replace("Korean step sentence", name + " step sentence"));
    }
  }
}
