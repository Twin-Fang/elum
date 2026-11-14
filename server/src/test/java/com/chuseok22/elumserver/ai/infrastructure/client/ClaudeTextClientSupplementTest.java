package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.ai.core.ContentLanguageSpec;
import com.chuseok22.elumserver.common.locale.AppLocale;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

/** 일과 만들기 보강 문구가 요청의 일과 언어를 말한다 (#1375). 깨지면 ja·zh·es 일과에 "한국어로만" 같은 반대 지시가 붙는다 */
class ClaudeTextClientSupplementTest {

  @ParameterizedTest
  @EnumSource(AppLocale.class)
  @DisplayName("보강의 출력 언어 자리는 그 언어 이름으로 채워지고 다른 언어 이름·빈 자리가 남지 않는다")
  void supplement_namesTheRoutineLanguage(AppLocale locale) {
    String supplement = ClaudeTextClient.routineCreateSupplementFor(locale);
    String languageName = ContentLanguageSpec.of(locale).englishName();

    assertThat(supplement).contains("only in " + languageName + ".").doesNotContain("{outputLanguage}");
    assertThat(supplement).contains("[Extra checks]").contains("imagePromptEn");
    if (locale != AppLocale.KO) {
      assertThat(supplement).doesNotContain("Korean").doesNotContain("한국어");
    }
  }
}
