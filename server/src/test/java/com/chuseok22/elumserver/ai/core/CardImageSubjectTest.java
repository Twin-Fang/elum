package com.chuseok22.elumserver.ai.core;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 카드 그림에서 캐릭터를 뺀 결정 (#1258) — 깨지면 Cloudflare 카드에 고양이·여우가 다시 그려진다
class CardImageSubjectTest {

  @Test
  @DisplayName("루루·포포·미선택 모두 카드 그림은 만화 아이")
  void forProfileCharacter_alwaysChild() {
    assertThat(CardImageSubject.forProfileCharacter(CharacterType.LULU)).isEqualTo(CardImageSubject.CHILD);
    assertThat(CardImageSubject.forProfileCharacter(CharacterType.POPO)).isEqualTo(CardImageSubject.CHILD);
    assertThat(CardImageSubject.forProfileCharacter(null)).isEqualTo(CardImageSubject.CHILD);
  }

  @Test
  @DisplayName("아이 생김새 기본값이 있고 성별 단어·색 코드가 없다")
  void childAppearanceDefault() {
    String appearance = PromptDefaults.DEFAULTS.get(CardImageSubject.CHILD.getAppearanceKey());
    assertThat(appearance).contains("bowl-cut").doesNotContain("boy").doesNotContain("girl").doesNotContain("#");
  }
}
