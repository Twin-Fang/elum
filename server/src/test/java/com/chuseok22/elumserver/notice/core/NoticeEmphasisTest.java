package com.chuseok22.elumserver.notice.core;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

/**
 * 제목 강조 표기 {@code **…**} (이슈 #370, N25).
 *
 * <p>짝이 안 맞으면 앱이 어디부터 강조할지 모른다. 관리자 저장에서 막는다.
 * 앱과 관리자 미리보기도 같은 규칙(왼쪽부터 {@code **} 로 나눠 홀수 번째 조각이 강조)으로 그린다.
 */
class NoticeEmphasisTest {

  @ParameterizedTest
  @ValueSource(strings = {
    "베타 기간 안내",
    "**하루 3개**까지 만들 수 있어요",
    "별도 설정 없이 **하이웍스와 연동**됩니다",
    "**하나** 그리고 **둘**",
  })
  @DisplayName("강조가 없거나 짝이 맞으면 통과한다")
  void paired(String title) {
    assertThat(NoticeEmphasis.isPaired(title)).isTrue();
  }

  @ParameterizedTest
  @ValueSource(strings = {
    "**하루 3개까지 만들 수 있어요",
    "하루 3개** 까지",
    "**하나** 그리고 **둘",
  })
  @DisplayName("짝이 안 맞으면 걸린다")
  void unpaired(String title) {
    assertThat(NoticeEmphasis.isPaired(title)).isFalse();
  }

  @Test
  @DisplayName("표기를 걷어낸 보이는 글자를 준다 — 비었는지는 이것으로 본다")
  void visibleText_stripsMarkers() {
    assertThat(NoticeEmphasis.visibleText("**하루 3개**까지")).isEqualTo("하루 3개까지");
    assertThat(NoticeEmphasis.visibleText("****")).isEmpty();
  }
}
