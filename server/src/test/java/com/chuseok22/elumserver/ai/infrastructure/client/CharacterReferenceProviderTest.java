package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class CharacterReferenceProviderTest {

  private final CharacterReferenceProvider characterReferenceProvider = new CharacterReferenceProvider();

  @Test
  @DisplayName("루루 캐릭터 이미지를 클래스패스에서 읽어 반환한다")
  void get_lulu_returnsNonEmptyBytes() {
    byte[] image = characterReferenceProvider.get(CharacterType.LULU);

    assertThat(image).isNotEmpty();
  }

  @Test
  @DisplayName("포포 캐릭터 이미지를 클래스패스에서 읽어 반환한다")
  void get_popo_returnsNonEmptyBytes() {
    byte[] image = characterReferenceProvider.get(CharacterType.POPO);

    assertThat(image).isNotEmpty();
  }
}
