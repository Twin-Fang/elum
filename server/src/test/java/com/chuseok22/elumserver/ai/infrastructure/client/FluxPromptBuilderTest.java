package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * FLUX 프롬프트 (#373).
 *
 * <p>schnell 은 한국어를 못 알아듣고(사람을 그렸다) 긴 지시문을 그림 속 글자로 찍었다. 그래서
 * 짧은 영어 한 덩어리 — 화풍 + 캐릭터 + 장면 한 줄 — 로만 보낸다. 2차 시험(#373)의 모양이다.
 */
class FluxPromptBuilderTest {

  private final FluxPromptBuilder builder = new FluxPromptBuilder();

  @Test
  @DisplayName("화풍 · 캐릭터 한 명 · 장면 순서로 붙이고, 장면의 'The character' 를 그 캐릭터 이름으로 바꾼다")
  void composesStyleCharacterScene() {
    String prompt = builder.build(
      "Flat vector illustration. Wordless image, no letters anywhere.",
      "The character pulls the bottom drawer of a small wooden dresser half open.",
      CharacterType.LULU);

    assertThat(prompt).isEqualTo(
      "Flat vector illustration. Wordless image, no letters anywhere. "
        + "Only one character: " + CharacterType.LULU.getAppearanceEn() + ". "
        + "The kitten pulls the bottom drawer of a small wooden dresser half open.");
    assertThat(prompt).doesNotContainPattern("[가-힣]");
  }

  @Test
  @DisplayName("문장 가운데의 the character 도 바꾼다 — 대소문자를 살려서")
  void replacesLowercaseSubject() {
    String prompt = builder.build("Style.", "A red umbrella leans on the wall next to the character.",
      CharacterType.POPO);

    assertThat(prompt).endsWith("A red umbrella leans on the wall next to the fox cub.");
  }

  @Test
  @DisplayName("캐릭터를 고르지 않은 회원이면 나이를 짐작하기 어려운 단순한 인물 한 명")
  void noCharacter_usesSimpleFigure() {
    String prompt = builder.build("Style.", "The character puts on a shirt.", null);

    assertThat(prompt).contains("Only one character: a simple friendly figure whose age is hard to guess.");
    assertThat(prompt).endsWith("The figure puts on a shirt.");
  }

  @Test
  @DisplayName("장면 줄바꿈·겹공백은 한 줄로 편다 — 여러 줄은 FLUX 가 글자로 찍기 쉽다")
  void flattensWhitespace() {
    String prompt = builder.build("Style.", "  The character\n waves.  ", CharacterType.LULU);

    assertThat(prompt).endsWith("The kitten waves.");
  }


  @Test
  @DisplayName("실사(#457)는 지시문 + 장면 한 줄뿐 — 'Only one character' 도 캐릭터·figure 치환도 없다")
  void realistic_hasNoCharacterConvention() {
    String prompt = builder.buildRealistic(
      "Realistic photo.  ", "  A small wooden dresser\n with the bottom drawer half open.  ");

    assertThat(prompt).isEqualTo("Realistic photo. A small wooden dresser with the bottom drawer half open.");
    assertThat(prompt).doesNotContain("Only one character").doesNotContain("figure");
  }

  @Test
  @DisplayName("만화 경로의 프롬프트 문자열은 그대로다 — 실사 추가가 기존 조립을 바꾸지 않는다")
  void cartoon_promptUnchanged() {
    assertThat(builder.build("Style.", "The character waves.", CharacterType.POPO))
      .isEqualTo("Style. Only one character: " + CharacterType.POPO.getAppearanceEn() + ". The fox cub waves.");
  }
}
