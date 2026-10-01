package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

class NicknamePlaceholderTest {

  static Stream<Arguments> restoreCases() {
    return Stream.of(
      // 받침 있음 / 없음 — 이름 마지막 글자 기준으로 조사를 다시 고른다
      Arguments.of("이룸이가 우산을 챙겨요", "하늘", "하늘이 우산을 챙겨요"),
      Arguments.of("이룸이가 우산을 챙겨요", "민지", "민지가 우산을 챙겨요"),
      Arguments.of("이룸이는 오늘 치과에 가요", "하늘", "하늘은 오늘 치과에 가요"),
      Arguments.of("이룸이는 오늘 치과에 가요", "민지", "민지는 오늘 치과에 가요"),
      Arguments.of("이룸이를 도와줘요", "하늘", "하늘을 도와줘요"),
      Arguments.of("이룸이를 도와줘요", "민지", "민지를 도와줘요"),
      Arguments.of("이룸이와 함께 가요", "하늘", "하늘과 함께 가요"),
      Arguments.of("이룸이와 함께 가요", "민지", "민지와 함께 가요"),
      Arguments.of("이룸이랑 같이 가요", "하늘", "하늘이랑 같이 가요"),
      Arguments.of("이룸이랑 같이 가요", "민지", "민지랑 같이 가요"),
      Arguments.of("이룸이예요", "하늘", "하늘이에요"),
      Arguments.of("이룸이예요", "민지", "민지예요"),
      Arguments.of("이룸이에요", "하늘", "하늘이에요"),
      Arguments.of("이룸이야, 일어나자", "하늘", "하늘아, 일어나자"),
      Arguments.of("이룸이야, 일어나자", "민지", "민지야, 일어나자"),
      // 로 — 받침 있으면 으로, ㄹ받침이면 그대로 로
      Arguments.of("이룸이로 정했어요", "하늘", "하늘로 정했어요"),
      Arguments.of("이룸이로 정했어요", "민석", "민석으로 정했어요"),
      Arguments.of("이룸이로 정했어요", "민지", "민지로 정했어요"),
      // 받침과 무관한 조사·뒤에 다른 글자가 붙은 꼴(E5)은 이름만 바꾼다
      Arguments.of("이룸이의 우산", "하늘", "하늘의 우산"),
      Arguments.of("이룸이에게 말해요", "하늘", "하늘에게 말해요"),
      Arguments.of("이룸이들이 모여요", "하늘", "하늘들이 모여요"),
      Arguments.of("이룸이 치과에 가요", "하늘", "하늘 치과에 가요"),
      // 영문·숫자로 끝나면 받침 없음 규칙(E3)
      Arguments.of("이룸이가 가요", "Dante", "Dante가 가요"),
      Arguments.of("이룸이는 가요", "Dante", "Dante는 가요"),
      Arguments.of("이룸이가 가요", "하늘2", "하늘2가 가요"),
      // 여러 번 나오면 모두
      Arguments.of("이룸이가 가요. 이룸이는 웃어요", "하늘", "하늘이 가요. 하늘은 웃어요"),
      // 이름 앞뒤 공백은 무시한다
      Arguments.of("이룸이가 가요", "  하늘 ", "하늘이 가요"),
      // 이름이 이룸이와 같거나 포함해도 깨지지 않는다(E7) — 한 번에 훑고 다시 치환하지 않는다
      Arguments.of("이룸이가 가요", "이룸이", "이룸이가 가요"),
      Arguments.of("이룸이는 가요", "이룸이2호", "이룸이2호는 가요"),
      Arguments.of("이룸이가 가요", "이룸", "이룸이 가요")
    );
  }

  @ParameterizedTest(name = "{0} / {1} -> {2}")
  @MethodSource("restoreCases")
  @DisplayName("restore: AI 문장의 이룸이를 실제 이름으로 바꾸고 조사를 받침에 맞춘다")
  void restore_fixesJosaByFinalConsonant(String text, String nickname, String expected) {
    assertThat(NicknamePlaceholder.restore(text, nickname)).isEqualTo(expected);
  }

  @Test
  @DisplayName("restore: 이름이 null·빈 값이면 치환하지 않고 이룸이를 그대로 둔다(E1)")
  void restore_blankNickname_leavesPlaceholder() {
    assertThat(NicknamePlaceholder.restore("이룸이가 가요", null)).isEqualTo("이룸이가 가요");
    assertThat(NicknamePlaceholder.restore("이룸이가 가요", "")).isEqualTo("이룸이가 가요");
    assertThat(NicknamePlaceholder.restore("이룸이가 가요", "   ")).isEqualTo("이룸이가 가요");
  }

  @Test
  @DisplayName("restore: AI 가 이룸이를 쓰지 않았거나 글이 null 이면 그대로(E4)")
  void restore_noPlaceholder_unchanged() {
    assertThat(NicknamePlaceholder.restore("우산을 챙겨요", "하늘")).isEqualTo("우산을 챙겨요");
    assertThat(NicknamePlaceholder.restore(null, "하늘")).isNull();
    assertThat(NicknamePlaceholder.restore("", "하늘")).isEmpty();
  }

  @Test
  @DisplayName("forAi: 이름이 있으면 자리표시, 없으면 null")
  void forAi_returnsPlaceholderOnlyWhenNameExists() {
    assertThat(NicknamePlaceholder.forAi("하늘")).isEqualTo("이룸이");
    assertThat(NicknamePlaceholder.forAi(null)).isNull();
    assertThat(NicknamePlaceholder.forAi(" ")).isNull();
  }

  static Stream<Arguments> maskCases() {
    return Stream.of(
      Arguments.of("하늘이가 치과에 가요", "하늘", "이룸이가 치과에 가요"),
      Arguments.of("하늘이는 우산이 필요해요", "하늘", "이룸이는 우산이 필요해요"),
      Arguments.of("민지가 학교에 가요", "민지", "이룸이가 학교에 가요"),
      Arguments.of("민지 학교에 가요", "민지", "이룸이 학교에 가요"),
      // 더 긴 낱말의 일부는 건드리지 않는다
      Arguments.of("하늘색 우산", "하늘", "하늘색 우산"),
      Arguments.of("하늘이름 쓰기", "하늘", "하늘이름 쓰기")
    );
  }

  @ParameterizedTest(name = "{0} / {1} -> {2}")
  @MethodSource("maskCases")
  @DisplayName("mask: 입력 글에 적힌 실제 이름을 AI 로 나가기 전에 이룸이로 바꾼다")
  void mask_replacesNameWithPlaceholder(String text, String nickname, String expected) {
    assertThat(NicknamePlaceholder.mask(text, nickname)).isEqualTo(expected);
  }

  @Test
  @DisplayName("mask: 이름이 없거나 한 글자이거나 자리표시 안에 들어가면 건드리지 않는다")
  void mask_unsafeNames_unchanged() {
    assertThat(NicknamePlaceholder.mask("하늘이가 가요", null)).isEqualTo("하늘이가 가요");
    assertThat(NicknamePlaceholder.mask("하늘이가 가요", " ")).isEqualTo("하늘이가 가요");
    assertThat(NicknamePlaceholder.mask("이룸이가 가요", "이룸")).isEqualTo("이룸이가 가요");
    assertThat(NicknamePlaceholder.mask("이룸이가 가요", "이룸이")).isEqualTo("이룸이가 가요");
    assertThat(NicknamePlaceholder.mask("민이가 가요", "민")).isEqualTo("민이가 가요");
    assertThat(NicknamePlaceholder.mask(null, "하늘")).isNull();
  }
}
