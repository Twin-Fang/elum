package com.chuseok22.elumserver.routine.infrastructure.constant;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class RewardPresetTest {

  @Test
  @DisplayName("정의된 프리셋 키는 대소문자와 무관하게 정규화된다")
  void normalize_acceptsDefinedKeys() {
    assertThat(RewardPreset.normalize("SNACK")).isEqualTo("SNACK");
    assertThat(RewardPreset.normalize("snack")).isEqualTo("SNACK");
    assertThat(RewardPreset.normalize("Video")).isEqualTo("VIDEO");
  }

  @Test
  @DisplayName("정의되지 않은 키는 null로 떨어진다")
  void normalize_rejectsUnknownKeys() {
    // 잘못된 키 때문에 일과 생성이 실패하면 안 된다 — 보상은 선택 항목이다.
    assertThat(RewardPreset.normalize("GIFT")).isNull();
    assertThat(RewardPreset.normalize("1234")).isNull();
  }

  @Test
  @DisplayName("null과 공백은 보상 미설정으로 본다")
  void normalize_treatsBlankAsUnset() {
    assertThat(RewardPreset.normalize(null)).isNull();
    assertThat(RewardPreset.normalize("")).isNull();
    assertThat(RewardPreset.normalize("   ")).isNull();
  }

  @Test
  @DisplayName("모든 프리셋은 사용자에게 보여줄 라벨을 갖는다")
  void allPresets_haveLabel() {
    for (RewardPreset preset : RewardPreset.values()) {
      assertThat(preset.getLabel()).isNotBlank();
    }
  }
}
