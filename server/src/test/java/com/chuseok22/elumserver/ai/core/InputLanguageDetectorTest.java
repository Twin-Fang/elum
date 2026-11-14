package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.EnumSet;
import java.util.Set;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 보호자 입력 글자 체계 > 일과 언어 (#1375). 깨지면 보호자가 쓴 언어와 다른 언어로 카드가 나온다 */
class InputLanguageDetectorTest {

  private static final Set<AppLocale> ALL = EnumSet.allOf(AppLocale.class);

  @Test
  @DisplayName("한글이 있으면 KO — 영어를 섞어 쓴 한국어 입력과 자모만 쓴 입력도")
  void hangul_isKorean() {
    assertThat(InputLanguageDetector.detect("양치하고 세수하기", AppLocale.EN)).contains(AppLocale.KO);
    assertThat(InputLanguageDetector.detect("My son runs away. 공원에서 엄마 옆에 있기 card pls", AppLocale.EN))
      .contains(AppLocale.KO);
    assertThat(InputLanguageDetector.detect("ㅁㄴㅇㄹ ㅋㅋ", AppLocale.ES)).contains(AppLocale.KO);
  }

  @Test
  @DisplayName("가나가 있으면 JA (한자가 섞여도)")
  void kana_isJapanese() {
    assertThat(InputLanguageDetector.detect("明日、学校に行く", AppLocale.KO)).contains(AppLocale.JA);
    assertThat(InputLanguageDetector.detect("ハミガキ", AppLocale.ZH)).contains(AppLocale.JA);
  }

  @Test
  @DisplayName("가나 없는 한자는 ZH, 화면이 ja 면 JA (\"病院\" 은 두 언어 공통)")
  void hanOnly_isChineseUnlessScreenIsJapanese() {
    assertThat(InputLanguageDetector.detect("门铃一响就去开门", AppLocale.KO)).contains(AppLocale.ZH);
    assertThat(InputLanguageDetector.detect("病院", AppLocale.EN)).contains(AppLocale.ZH);
    assertThat(InputLanguageDetector.detect("病院", AppLocale.JA)).contains(AppLocale.JA);
  }

  @Test
  @DisplayName("라틴 글은 화면이 ES 면 ES, EN 이면 EN, 그 밖(ko·ja·zh 화면)은 EN")
  void latin_tieBreakByScreenLanguage() {
    assertThat(InputLanguageDetector.detect("Lavarse los dientes", AppLocale.ES)).contains(AppLocale.ES);
    assertThat(InputLanguageDetector.detect("brush teeth", AppLocale.EN)).contains(AppLocale.EN);
    assertThat(InputLanguageDetector.detect("brush teeth", AppLocale.KO)).contains(AppLocale.EN);
    assertThat(InputLanguageDetector.detect("Médico", AppLocale.JA)).contains(AppLocale.EN);
  }

  @Test
  @DisplayName("글자가 없으면(빈 글, 이모지·숫자만) 판정하지 않는다")
  void noLetters_isEmpty() {
    assertThat(InputLanguageDetector.detect(null, AppLocale.KO)).isEmpty();
    assertThat(InputLanguageDetector.detect("   ", AppLocale.KO)).isEmpty();
    assertThat(InputLanguageDetector.detect("🦷🪥 3!!!", AppLocale.KO)).isEmpty();
  }

  @Test
  @DisplayName("판정 언어가 켜져 있으면 그것, 꺼져 있거나 판정이 안 되면 fallback(화면 언어 기준 값)")
  void resolve_onlyEnabledLocales() {
    Set<AppLocale> koAndEn = EnumSet.of(AppLocale.KO, AppLocale.EN);

    assertThat(InputLanguageDetector.resolve("明日、学校に行く", AppLocale.EN, ALL, AppLocale.EN)).isEqualTo(AppLocale.JA);
    assertThat(InputLanguageDetector.resolve("양치", AppLocale.EN, koAndEn, AppLocale.EN)).isEqualTo(AppLocale.KO);
    assertThat(InputLanguageDetector.resolve("明日、学校に行く", AppLocale.JA, koAndEn, AppLocale.EN)).isEqualTo(AppLocale.EN);
    assertThat(InputLanguageDetector.resolve("Lavarse los dientes", AppLocale.ES, koAndEn, AppLocale.EN))
      .isEqualTo(AppLocale.EN);
    assertThat(InputLanguageDetector.resolve("🦷", AppLocale.ES, ALL, AppLocale.ES)).isEqualTo(AppLocale.ES);
  }
}
