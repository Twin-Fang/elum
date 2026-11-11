package com.chuseok22.elumserver.common.text;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

/// AI 카드 문장 목적격 조사 보정 (#1190): 틀린 조사만 고치고, '을' 로 끝나는 낱말은 건드리지 않음
class ObjectParticleFixerTest {

  @ParameterizedTest(name = "{0} > {1}")
  @DisplayName("받침 없는 낱말 + 을 > 를, 받침 있는 낱말 + 를 > 을 — 이룸이가 틀린 말을 매일 듣지 않게")
  @CsvSource({
    "수도꼭지을 닫아요, 수도꼭지를 닫아요",
    "물컵를 챙겨요, 물컵을 챙겨요",
    "물를 마셔요, 물을 마셔요",
    "차을., 차를.",
    "의자을, 의자를",
    "가방를 메고 신발를 신어요, 가방을 메고 신발을 신어요"
  })
  void wrongParticle_isFixed(String aiText, String expected) {
    assertThat(ObjectParticleFixer.fix(aiText)).isEqualTo(expected);
  }

  @ParameterizedTest(name = "{0}")
  @DisplayName("맞는 조사와 '을' 로 끝나는 낱말(가을·마을·노을, 지을·부을)은 그대로 — 맞는 말을 틀리게 바꾸지 않게")
  @CsvSource({
    "이를 닦아요",
    "옷을 입어요",
    "가을 옷을 입어요",
    "시골마을 길을 걸어요",
    "저녁노을 봐요",
    "밥을 지을 거예요",
    "물을 부을 거예요",
    "다를 거예요",
    "을지로에 가요",
    "TV을 꺼요"
  })
  void correctOrWordFinalEul_isKept(String aiText) {
    assertThat(ObjectParticleFixer.fix(aiText)).isEqualTo(aiText);
  }

  @Test
  @DisplayName("null·빈 글은 그대로 돌려준다")
  void nullOrBlank_isReturnedAsIs() {
    assertThat(ObjectParticleFixer.fix(null)).isNull();
    assertThat(ObjectParticleFixer.fix("")).isEmpty();
  }
}
