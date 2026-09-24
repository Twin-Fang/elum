package com.chuseok22.elumserver.member.infrastructure.entity;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class CharacterTypeTest {

  @Test
  @DisplayName("모든 캐릭터가 영어 생김새를 가진다 — 한국어·색 코드 없이 (#375 · #373)")
  void everyCharacter_hasEnglishAppearance() {
    for (CharacterType type : CharacterType.values()) {
      assertThat(type.getAppearanceEn()).as(type.name()).isNotBlank()
        .doesNotContainPattern("[가-힣]")
        // FLUX 는 '#EFEDE8' 같은 문자열을 그림 속 글자로 찍는다. 색은 이름으로 적는다.
        .doesNotContain("#");
      assertThat(type.getSubjectEn()).as(type.name()).isNotBlank().doesNotContainPattern("[가-힣]");
    }
  }
}
