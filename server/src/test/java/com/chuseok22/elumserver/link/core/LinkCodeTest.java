package com.chuseok22.elumserver.link.core;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.stream.IntStream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 연결 암호 규칙 (이슈 #200 · 명세 §5-0).
 *
 * <p>보호자가 불러주고 이룸이가 받아적는다. 헷갈리는 글자가 하나라도 섞이면
 * 그 자리에서 막히므로, "웬만하면 안 나온다"가 아니라 **한 번도 안 나온다**를 고정한다.
 */
class LinkCodeTest {

  @Test
  @DisplayName("헷갈리는 글자(0 O 1 I L U)는 만들지 않는다")
  void generate_neverContainsConfusingCharacters() {
    String banned = "0O1ILU";

    IntStream.range(0, 3000).forEach(i -> {
      String code = LinkCode.generate();
      assertThat(code).hasSize(6);
      for (char c : banned.toCharArray()) {
        assertThat(code)
          .withFailMessage("%d번째 생성에서 금지 문자 '%c'가 나왔습니다: %s", i, c, code)
          .doesNotContain(String.valueOf(c));
      }
    });
  }

  @Test
  @DisplayName("소문자로 쳐도 대문자로 받는다")
  void normalize_upperCases() {
    assertThat(LinkCode.normalize("a7k3m9")).isEqualTo("A7K3M9");
  }

  @Test
  @DisplayName("화면이 3-3으로 보여주므로 사이 공백을 받아준다")
  void normalize_stripsSpacing() {
    assertThat(LinkCode.normalize("A7K 3M9")).isEqualTo("A7K3M9");
    assertThat(LinkCode.normalize("A7K-3M9")).isEqualTo("A7K3M9");
  }

  @Test
  @DisplayName("null 이 와도 터지지 않는다")
  void normalize_nullSafe() {
    assertThat(LinkCode.normalize(null)).isEmpty();
  }

  @Test
  @DisplayName("우리가 만들 수 없는 모양은 걸러낸다")
  void hasValidShape() {
    assertThat(LinkCode.hasValidShape("A7K3M9")).isTrue();
    assertThat(LinkCode.hasValidShape("A7K3M")).isFalse();     // 5자리
    assertThat(LinkCode.hasValidShape("A7K3M99")).isFalse();   // 7자리
    assertThat(LinkCode.hasValidShape("A0K3M9")).isFalse();    // 금지 문자 0
    assertThat(LinkCode.hasValidShape("A7K3M!")).isFalse();    // 특수문자
  }

  @Test
  @DisplayName("알파벳은 30자다 — 6자리로 7억 가지")
  void alphabetSize() {
    assertThat(LinkCode.ALPHABET).hasSize(30);
    assertThat(LinkCode.ALPHABET.chars().distinct().count()).isEqualTo(30);
  }
}
