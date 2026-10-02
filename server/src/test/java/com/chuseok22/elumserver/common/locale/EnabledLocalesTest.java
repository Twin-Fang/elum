package com.chuseok22.elumserver.common.locale;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class EnabledLocalesTest {

  private EnabledLocales enabledWith(String configured) {
    SystemConfigService config = mock(SystemConfigService.class);
    when(config.getString(ConfigKey.ENABLED_CONTENT_LOCALES)).thenReturn(configured);
    return new EnabledLocales(config);
  }

  @Test
  @DisplayName("기본값은 ko 하나다 — 배포만으로는 동작이 바뀌지 않는다")
  void default_isKoOnly() {
    assertThat(ConfigKey.ENABLED_CONTENT_LOCALES.getDefaultValue()).isEqualTo("ko");
    assertThat(enabledWith("ko").current()).containsExactly(AppLocale.KO);
  }

  @Test
  @DisplayName("켠 언어를 읽고 ko 는 늘 켜져 있다")
  void parse_enabled() {
    assertThat(enabledWith("en, ja").current()).containsExactly(AppLocale.KO, AppLocale.EN, AppLocale.JA);
    assertThat(enabledWith("ko,en").contains(AppLocale.EN)).isTrue();
    assertThat(enabledWith("en").contains(AppLocale.KO)).isTrue();
    assertThat(enabledWith("ko").contains(AppLocale.JA)).isFalse();
  }

  @ParameterizedTest
  @ValueSource(strings = {"xx", "", " ", ",", "zh-Hans", "ko,xx", "null"})
  @DisplayName("잘못된 값은 터지지 않고 ko 만 켜진 것으로 읽는다 (알 수 없는 코드는 건너뛴다)")
  void parse_brokenValues_neverThrow(String configured) {
    assertThat(enabledWith(configured).current()).contains(AppLocale.KO).doesNotContain(AppLocale.JA);
  }

  @Test
  @DisplayName("알 수 없는 코드가 섞여 있어도 유효한 코드는 살린다")
  void parse_keepsValidTokens() {
    assertThat(enabledWith("ko,xx,en").current()).containsExactly(AppLocale.KO, AppLocale.EN);
  }

  @Test
  @DisplayName("설정을 읽지 못해도 ko 로 동작한다")
  void configFailure_isKoOnly() {
    SystemConfigService config = mock(SystemConfigService.class);
    when(config.getString(ConfigKey.ENABLED_CONTENT_LOCALES)).thenThrow(new IllegalStateException("db down"));

    assertThat(new EnabledLocales(config).current()).containsExactly(AppLocale.KO);
  }

  @Test
  @DisplayName("요청 언어가 켜져 있으면 그 언어, 아니면 en 이 켜져 있을 때 en, 아니면 ko")
  void resolveContentLocale() {
    EnabledLocales withEn = enabledWith("ko,en,ja");
    assertThat(withEn.resolveContentLocale(AppLocale.JA)).isEqualTo(AppLocale.JA);
    assertThat(withEn.resolveContentLocale(AppLocale.ZH)).isEqualTo(AppLocale.EN);
    assertThat(withEn.resolveContentLocale(AppLocale.KO)).isEqualTo(AppLocale.KO);

    EnabledLocales koOnly = enabledWith("ko");
    assertThat(koOnly.resolveContentLocale(AppLocale.JA)).isEqualTo(AppLocale.KO);
    assertThat(koOnly.resolveContentLocale(AppLocale.EN)).isEqualTo(AppLocale.KO);
    assertThat(koOnly.resolveContentLocale(AppLocale.KO)).isEqualTo(AppLocale.KO);

    EnabledLocales jaWithoutEn = enabledWith("ko,ja");
    assertThat(jaWithoutEn.resolveContentLocale(AppLocale.ES)).isEqualTo(AppLocale.KO);
  }

  @Test
  @DisplayName("저장 검증: 정규화해서 ko 를 앞에 붙이고 enum 순서로 정렬한다")
  void normalize_ok() {
    assertThat(EnabledLocales.normalize("en")).isEqualTo("ko,en");
    assertThat(EnabledLocales.normalize("EN, ja")).isEqualTo("ko,en,ja");
    assertThat(EnabledLocales.normalize("es,ko,es,ja")).isEqualTo("ko,ja,es");
  }

  @ParameterizedTest
  @ValueSource(strings = {"xx", "", " ", ",", "ko,xx", "zh-Hans", "ko;en"})
  @DisplayName("저장 검증: 모르는 코드나 빈 값은 SYSTEM_CONFIG_INVALID_VALUE")
  void normalize_rejects(String csv) {
    assertThatThrownBy(() -> EnabledLocales.normalize(csv))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.SYSTEM_CONFIG_INVALID_VALUE);
  }
}
