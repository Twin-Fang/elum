package com.chuseok22.elumserver.adreward.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.lenient;

import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.Duration;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 광고 보상 설정을 읽는 방식 (#463). 값이 이상해도 **크레딧이 새는 쪽으로는 절대 읽지 않는다.**
 */
@ExtendWith(MockitoExtension.class)
class AdRewardSettingsTest {

  @Mock
  private SystemConfigService config;

  private AdRewardSettings settings;

  @BeforeEach
  void setUp() {
    settings = new AdRewardSettings(config);
    lenient().when(config.getBoolean(ConfigKey.AD_REWARD_ENABLED)).thenReturn(true);
    lenient().when(config.getInt(ConfigKey.AD_REWARD_CREDITS_PER_VIEW)).thenReturn(2);
    lenient().when(config.getInt(ConfigKey.AD_REWARD_DAILY_LIMIT)).thenReturn(5);
    lenient().when(config.getInt(ConfigKey.AD_REWARD_SESSION_TTL_MINUTES)).thenReturn(30);
    lenient().when(config.getString(ConfigKey.AD_REWARD_ALLOWED_AD_UNITS)).thenReturn("8857966475,6517734434");
  }

  @Test
  void 기본_설정은_꺼짐이다() {
    // 배포만으로는 동작이 바뀌지 않아야 한다.
    assertThat(ConfigKey.AD_REWARD_ENABLED.getDefaultValue()).isEqualTo("false");
  }

  @Test
  void 켜져_있고_지급량과_상한이_양수면_켜진_것이다() {
    assertThat(settings.enabled()).isTrue();
  }

  @Test
  void 켜기를_꺼도_지급량이_0_이하도_상한이_0_이하도_꺼진_것이다() {
    lenient().when(config.getBoolean(ConfigKey.AD_REWARD_ENABLED)).thenReturn(false);
    assertThat(settings.enabled()).isFalse();

    lenient().when(config.getBoolean(ConfigKey.AD_REWARD_ENABLED)).thenReturn(true);
    lenient().when(config.getInt(ConfigKey.AD_REWARD_CREDITS_PER_VIEW)).thenReturn(0);
    assertThat(settings.enabled()).isFalse();

    lenient().when(config.getInt(ConfigKey.AD_REWARD_CREDITS_PER_VIEW)).thenReturn(2);
    lenient().when(config.getInt(ConfigKey.AD_REWARD_DAILY_LIMIT)).thenReturn(0);
    assertThat(settings.enabled()).isFalse();
  }

  @Test
  void 음수는_0으로_읽는다() {
    lenient().when(config.getInt(ConfigKey.AD_REWARD_CREDITS_PER_VIEW)).thenReturn(-5);
    lenient().when(config.getInt(ConfigKey.AD_REWARD_DAILY_LIMIT)).thenReturn(-1);

    assertThat(settings.creditsPerView()).isZero();
    assertThat(settings.dailyLimit()).isZero();
    assertThat(settings.enabled()).isFalse();
  }

  @Test
  void 세션_유효_시간은_최소_1분이다() {
    lenient().when(config.getInt(ConfigKey.AD_REWARD_SESSION_TTL_MINUTES)).thenReturn(0);

    assertThat(settings.sessionTtl()).isEqualTo(Duration.ofMinutes(1));
  }

  @Test
  void 허용_목록은_숫자로도_전체_ID로도_맞춘다() {
    assertThat(settings.isAllowedAdUnit("6517734434")).isTrue();
    assertThat(settings.isAllowedAdUnit("ca-app-pub-2025665624324395/8857966475")).isTrue();
    assertThat(settings.isAllowedAdUnit("1111111111")).isFalse();
  }

  @Test
  void 목록에_전체_ID가_들어_있어도_숫자로_맞춘다() {
    lenient().when(config.getString(ConfigKey.AD_REWARD_ALLOWED_AD_UNITS))
      .thenReturn(" ca-app-pub-2025665624324395/8857966475 , 6517734434 ");

    assertThat(settings.isAllowedAdUnit("8857966475")).isTrue();
    assertThat(settings.isAllowedAdUnit("6517734434")).isTrue();
  }

  @Test
  void 목록이_비면_아무것도_허용하지_않는다() {
    lenient().when(config.getString(ConfigKey.AD_REWARD_ALLOWED_AD_UNITS)).thenReturn("");

    assertThat(settings.isAllowedAdUnit("6517734434")).isFalse();
    assertThat(settings.isAllowedAdUnit("")).isFalse();
    assertThat(settings.isAllowedAdUnit(null)).isFalse();
  }
}
