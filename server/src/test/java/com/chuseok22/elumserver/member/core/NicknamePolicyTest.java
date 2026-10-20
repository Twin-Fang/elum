package com.chuseok22.elumserver.member.core;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

/// 판정이 틀리면 욕설 닉네임이 다른 보호자에게 보이거나, 정상 이름이 막혀 바꾸지 못한다.
class NicknamePolicyTest {

  private final NicknamePolicy nicknamePolicy = new NicknamePolicy();

  private NicknameVerdict judgeRaw(String rawNickname) {
    return nicknamePolicy.judge(nicknamePolicy.normalize(rawNickname));
  }

  @ParameterizedTest
  @ValueSource(strings = {
    "가", "가나다라마바사아자차카타파하가나다", "푸른 하늘", "ㅋㅋㅋ", "ㅅㅂ하늘", "하늘😀", "하늘​", "", "하늘_7"})
  void 형식이_맞지_않으면_INVALID_FORMAT(String rawNickname) {
    assertThat(judgeRaw(rawNickname)).isEqualTo(NicknameVerdict.INVALID_FORMAT);
  }

  @Test
  void 입력이_null_이면_INVALID_FORMAT() {
    assertThat(judgeRaw(null)).isEqualTo(NicknameVerdict.INVALID_FORMAT);
  }

  @ParameterizedTest
  @ValueSource(strings = {
    "시발놈", "시1발", "씨-발", "개새끼7", "sh1t-man", "FUCK", "Fu-ck", "b1tch", "kusoman", "caonima1",
    "puta-loca", "sh11t", "fuuuck", "관리자", "admin-1", "Admin1", "elum공식", "이룸팀장"})
  void 욕설이나_예약어가_들어가면_NOT_ALLOWED(String rawNickname) {
    assertThat(judgeRaw(rawNickname)).isEqualTo(NicknameVerdict.NOT_ALLOWED);
  }

  @ParameterizedTest
  @ValueSource(strings = {
    "가파른블록-1269", "가파른블록-12345678", "푸른하늘", "Sky-7", "시발점", "시바견", "Sussex7", "cocktail", "ab", "Hancock", "Vergara", "새끼손가락", "Wessex",
    "가나다라마바사아자차카타파하가나"})
  void 정상_이름은_ALLOWED(String rawNickname) {
    assertThat(judgeRaw(rawNickname)).isEqualTo(NicknameVerdict.ALLOWED);
  }

  @Test
  void 앞뒤_공백과_전각_문자를_정리한다() {
    assertThat(nicknamePolicy.normalize("  ａｂｃ  ")).isEqualTo("abc");
    assertThat(judgeRaw("  ａｂｃ  ")).isEqualTo(NicknameVerdict.ALLOWED);
  }
}
