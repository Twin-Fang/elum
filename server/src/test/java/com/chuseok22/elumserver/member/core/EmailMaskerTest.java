package com.chuseok22.elumserver.member.core;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class EmailMaskerTest {

  // 깨지면: 내 정보 화면에 보호자 이메일 원문이 그대로 노출됨
  @Test
  @DisplayName("아이디는 앞 2자만 남기고 도메인은 보인다")
  void masksLocalPart() {
    assertThat(EmailMasker.mask("abcdef@gmail.com")).isEqualTo("ab***@gmail.com");
  }

  // 깨지면: 짧은 아이디(ab@)가 가린 표시로도 전부 드러남
  @Test
  @DisplayName("아이디가 2자 이하면 첫 글자만 남긴다")
  void shortLocalPartKeepsOneCharacter() {
    assertThat(EmailMasker.mask("ab@naver.com")).isEqualTo("a***@naver.com");
  }

  // 깨지면: 이메일 없는 계정·애플 숨김 계정에 의미 없는 주소가 보이거나 화면이 깨짐
  @Test
  @DisplayName("이메일이 없거나 애플 숨김 주소·형식이 깨진 값이면 null")
  void returnsNullWhenPrivateOrInvalid() {
    assertThat(EmailMasker.mask(null)).isNull();
    assertThat(EmailMasker.mask("x1y2z3@privaterelay.appleid.com")).isNull();
    assertThat(EmailMasker.mask("not-an-email")).isNull();
    assertThat(EmailMasker.mask("@gmail.com")).isNull();
  }
}
