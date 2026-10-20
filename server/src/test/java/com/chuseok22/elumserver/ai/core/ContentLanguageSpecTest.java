package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.lang.reflect.RecordComponent;
import java.util.regex.Pattern;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

class ContentLanguageSpecTest {

  private static final Pattern HANGUL = Pattern.compile("[\\uAC00-\\uD7A3\\u3131-\\u318E]");

  @Test
  @DisplayName("ko 스키마 문구는 지금 코드에 박힌 한국어 문장과 글자까지 같다 — ko 요청 본문이 바뀌지 않는다")
  void ko_hintsAreTheCurrentLiterals() {
    ContentLanguageSpec ko = ContentLanguageSpec.of(AppLocale.KO);

    assertThat(ko.routineTitleHint())
      .isEqualTo("일과 전체를 아우르는 제목. '~해요' 체로 작성 (예: '비오는 날 학교에 가요')");
    assertThat(ko.stepTitleHint())
      .isEqualTo("카드에 크게 표시할 2~4어절짜리 짧은 라벨. '~해요' 체 (예: '옷을 입어요')");
    assertThat(ko.stepDescriptionHint())
      .isEqualTo("소리 내어 읽어줄 아주 짧은 한 문장. 공백 포함 12자 안팎, 행동 하나만. "
        + "'~고', '~해서', '~한 뒤', 쉼표로 행동을 잇지 않는다 (나쁜 예: '이불을 덮고 누워요', 좋은 예: '침대에 누워요'). "
        + "title을 되풀이하지 않고 쉬운 말로 (예: '학교 갈 옷을 입어요')");
  }

  @Test
  @DisplayName("다섯 언어 모두 사양이 있고 자기 언어를 가리킨다")
  void everyLocaleHasSpec() {
    for (AppLocale locale : AppLocale.values()) {
      assertThat(ContentLanguageSpec.of(locale).locale()).isEqualTo(locale);
    }
  }

  @ParameterizedTest
  @EnumSource(value = AppLocale.class, names = "KO", mode = EnumSource.Mode.EXCLUDE)
  @DisplayName("ko 가 아닌 사양은 모든 칸이 차 있고 한글이 섞이지 않는다 — 번역 누락·복붙 사고를 막는다")
  void nonKo_everyFieldFilledAndHangulFree(AppLocale locale) throws Exception {
    ContentLanguageSpec spec = ContentLanguageSpec.of(locale);

    for (RecordComponent component : ContentLanguageSpec.class.getRecordComponents()) {
      Object value = component.getAccessor().invoke(spec);
      if (value instanceof String text) {
        assertThat(text).as("%s.%s", locale, component.getName()).isNotBlank();
        assertThat(HANGUL.matcher(text).find()).as("%s.%s 에 한글", locale, component.getName()).isFalse();
      }
    }
  }
}
