package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

class NicknamePlaceholderLocaleTest {

  static Stream<Arguments> restoreCases() {
    return Stream.of(
      // 조사가 없는 언어 — 자리표시를 이름으로 그대로 바꾼다
      Arguments.of(AppLocale.EN, "Elumi puts on shoes", "Haneul", "Haneul puts on shoes"),
      Arguments.of(AppLocale.EN, "Pack Elumi's bag. Elumi is ready", "Haneul", "Pack Haneul's bag. Haneul is ready"),
      Arguments.of(AppLocale.ES, "Elumi se pone los zapatos", "Haneul", "Haneul se pone los zapatos"),
      // 일본어·중국어는 자리표시 바로 뒤에 글자가 붙는다 — 그래도 이름만 바꾼다
      Arguments.of(AppLocale.JA, "Elumiは靴をはきます", "ハル", "ハルは靴をはきます"),
      Arguments.of(AppLocale.ZH, "Elumi穿上衣服", "小明", "小明穿上衣服"),
      // 더 긴 영문 낱말의 일부는 자리표시가 아니다
      Arguments.of(AppLocale.EN, "Elumikoko is here", "Haneul", "Elumikoko is here"),
      Arguments.of(AppLocale.EN, "xElumi is here", "Haneul", "xElumi is here"),
      // 이름에 $ 나 \ 가 있어도 글자 그대로 들어간다
      Arguments.of(AppLocale.EN, "Elumi runs", "A$1\\b", "A$1\\b runs"),
      // 이름 앞뒤 공백은 무시한다
      Arguments.of(AppLocale.EN, "Elumi runs", "  Haneul ", "Haneul runs")
    );
  }

  @ParameterizedTest(name = "{0}: {1} / {2} -> {3}")
  @MethodSource("restoreCases")
  @DisplayName("restore: ko 가 아닌 언어는 자리표시를 이름으로 직접 바꾼다")
  void restore_nonKo(AppLocale locale, String text, String nickname, String expected) {
    assertThat(NicknamePlaceholder.restore(text, nickname, locale)).isEqualTo(expected);
  }

  @Test
  @DisplayName("restore: 이름이 비었거나 글이 null 이면 그대로 둔다 — 던지지 않는다")
  void restore_blankOrNull() {
    assertThat(NicknamePlaceholder.restore("Elumi runs", " ", AppLocale.EN)).isEqualTo("Elumi runs");
    assertThat(NicknamePlaceholder.restore("Elumi runs", null, AppLocale.EN)).isEqualTo("Elumi runs");
    assertThat(NicknamePlaceholder.restore(null, "Haneul", AppLocale.EN)).isNull();
  }

  static Stream<Arguments> maskCases() {
    return Stream.of(
      Arguments.of(AppLocale.EN, "Haneul needs an umbrella", "Haneul", "Elumi needs an umbrella"),
      Arguments.of(AppLocale.ES, "Haneul lleva el paraguas", "Haneul", "Elumi lleva el paraguas"),
      // 영문 이름은 낱말 경계로 — 더 긴 낱말은 건드리지 않는다
      Arguments.of(AppLocale.EN, "Haneulish plan", "Haneul", "Haneulish plan"),
      // 한자·가나·한글 이름은 뒤에 조사·어미가 바로 붙어 경계를 볼 수 없다
      Arguments.of(AppLocale.JA, "ハルはかさをもつ", "ハル", "Elumiはかさをもつ"),
      Arguments.of(AppLocale.ZH, "小明带上雨伞", "小明", "Elumi带上雨伞"),
      // 한 글자 이름, 자리표시 안에 들어가는 이름은 건드리지 않는다
      Arguments.of(AppLocale.EN, "A runs", "A", "A runs"),
      // 자리표시의 일부인 짧은 이름도 낱말 경계로 찾아 가린다
      Arguments.of(AppLocale.EN, "Mi runs", "Mi", "Elumi runs"),
      Arguments.of(AppLocale.EN, "Lu runs", "Lu", "Elumi runs"),
      Arguments.of(AppLocale.EN, "Eli runs", "Eli", "Elumi runs"),
      Arguments.of(AppLocale.EN, "Elu runs", "Elu", "Elumi runs"),
      // 자리표시와 같은 이름은 그대로 둔다
      Arguments.of(AppLocale.EN, "Elumi runs", "Elumi", "Elumi runs")
    );
  }

  @ParameterizedTest(name = "{0}: {1} / {2} -> {3}")
  @MethodSource("maskCases")
  @DisplayName("mask: ko 가 아닌 언어는 글에 적힌 실제 이름을 자리표시로 바꾼다 (AI 로 나가기 전)")
  void mask_nonKo(AppLocale locale, String text, String nickname, String expected) {
    assertThat(NicknamePlaceholder.mask(text, nickname, locale)).isEqualTo(expected);
  }

  @Test
  @DisplayName("forAi: 이름이 있으면 그 언어의 자리표시, 없으면 null")
  void forAi() {
    assertThat(NicknamePlaceholder.forAi("하늘", AppLocale.KO)).isEqualTo("이룸이");
    assertThat(NicknamePlaceholder.forAi("Haneul", AppLocale.EN)).isEqualTo("Elumi");
    assertThat(NicknamePlaceholder.forAi(" ", AppLocale.JA)).isNull();
    assertThat(NicknamePlaceholder.forAi(null, AppLocale.ZH)).isNull();
  }

  @Test
  @DisplayName("ko 는 지금과 같다 — 3-인자 KO 는 2-인자와 결과가 같고, Elumi 는 건드리지 않는다")
  void ko_isUnchanged() {
    assertThat(NicknamePlaceholder.restore("이룸이가 우산을 챙겨요", "하늘", AppLocale.KO))
      .isEqualTo(NicknamePlaceholder.restore("이룸이가 우산을 챙겨요", "하늘"))
      .isEqualTo("하늘이 우산을 챙겨요");
    assertThat(NicknamePlaceholder.mask("하늘이가 우산을 챙겨요", "하늘", AppLocale.KO))
      .isEqualTo(NicknamePlaceholder.mask("하늘이가 우산을 챙겨요", "하늘"));
    assertThat(NicknamePlaceholder.forAi("하늘", AppLocale.KO)).isEqualTo(NicknamePlaceholder.forAi("하늘"));
    assertThat(NicknamePlaceholder.restore("Elumi runs", "Haneul", AppLocale.KO)).isEqualTo("Elumi runs");
  }

  @Test
  @DisplayName("restore 와 mask 는 서로 되돌린다 — 영어")
  void roundTrip() {
    String masked = NicknamePlaceholder.mask("Haneul packs the bag", "Haneul", AppLocale.EN);
    assertThat(NicknamePlaceholder.restore(masked, "Haneul", AppLocale.EN)).isEqualTo("Haneul packs the bag");
  }
}
