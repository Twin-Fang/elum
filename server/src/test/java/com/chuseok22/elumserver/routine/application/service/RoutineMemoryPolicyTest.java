package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 자동 적용 횟수: 깨지면 설정 오타(0·1·99)로 한 번 고친 것이 바로 적용되거나 영영 적용되지 않는다
 */
@ExtendWith(MockitoExtension.class)
class RoutineMemoryPolicyTest {

  @Mock private SystemConfigService systemConfigService;
  @InjectMocks private RoutineMemoryPolicy policy;

  @Test
  @DisplayName("설정이 2~10 이면 그대로, 범위 밖이면 기본 3 으로 대신한다")
  void autoApplyCount_clampsToDefault() {
    when(systemConfigService.getInt(ConfigKey.ROUTINE_MEMORY_AUTO_APPLY_COUNT)).thenReturn(2, 10, 1, 11, 0, 5);

    assertThat(policy.autoApplyCount()).isEqualTo(2);
    assertThat(policy.autoApplyCount()).isEqualTo(10);
    assertThat(policy.autoApplyCount()).isEqualTo(3);
    assertThat(policy.autoApplyCount()).isEqualTo(3);
    assertThat(policy.autoApplyCount()).isEqualTo(3);
    assertThat(policy.autoApplyCount()).isEqualTo(5);
  }

  @Test
  @DisplayName("설정 기본값은 3 이고 범위는 2~10 이다")
  void configDefault_isThreeWithinTwoToTen() {
    assertThat(ConfigKey.ROUTINE_MEMORY_AUTO_APPLY_COUNT.getDefaultValue()).isEqualTo("3");
    assertThat(ConfigKey.ROUTINE_MEMORY_AUTO_APPLY_COUNT.getMinValue()).isEqualTo(2);
    assertThat(ConfigKey.ROUTINE_MEMORY_AUTO_APPLY_COUNT.getMaxValue()).isEqualTo(10);
  }
}
