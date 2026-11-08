package com.chuseok22.elumserver.systemconfig.core;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.service.SettingsSection;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/// 관제소 연동 설정: 켜기 하나만(토큰은 환경 변수), 기본 꺼짐이라 배포만으로는 내보내지 않음, 시스템 설정 화면에 나옴 (#1229)
class ControlTowerConfigKeyTest {

  @Test
  @DisplayName("관제소 연동 그룹은 켜기 1개, BOOLEAN 기본 꺼짐, 시스템 설정 화면")
  void controlTowerGroup_hasOnlyDisabledByDefaultToggle() {
    List<ConfigKey> controlTowerKeys =
      Arrays.stream(ConfigKey.values()).filter(key -> key.getGroup() == ConfigGroup.CONTROL_TOWER).toList();

    assertThat(controlTowerKeys).containsExactly(ConfigKey.CONTROL_TOWER_ATTENTION_ENABLED);
    assertThat(ConfigKey.CONTROL_TOWER_ATTENTION_ENABLED.getValueType()).isEqualTo(ConfigValueType.BOOLEAN);
    assertThat(ConfigKey.CONTROL_TOWER_ATTENTION_ENABLED.getDefaultValue()).isEqualTo("false");
    assertThat(SettingsSection.of(ConfigKey.CONTROL_TOWER_ATTENTION_ENABLED)).isEqualTo(SettingsSection.SYSTEM);
  }
}
