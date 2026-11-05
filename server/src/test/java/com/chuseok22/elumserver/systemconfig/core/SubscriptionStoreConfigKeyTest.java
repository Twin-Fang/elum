package com.chuseok22.elumserver.systemconfig.core;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.systemconfig.application.service.ConfigValueCheck;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigValueValidator;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 스토어 구독 설정 기본값: 배포만으로 결제가 켜지거나 테스트 결제가 Pro 를 받지 않는가, 긴 비밀값(JSON 키)을 저장할 수 있는가
 */
class SubscriptionStoreConfigKeyTest {

  @Test
  @DisplayName("켜기·신규 판매·테스트 결제 허용은 기본 꺼짐, 상품 목록·비밀값은 비어 있다")
  void defaults_keepProductionUnchanged() {
    assertThat(ConfigKey.SUBSCRIPTION_APPLE_ENABLED.getDefaultValue()).isEqualTo("false");
    assertThat(ConfigKey.SUBSCRIPTION_GOOGLE_ENABLED.getDefaultValue()).isEqualTo("false");
    assertThat(ConfigKey.SUBSCRIPTION_APPLE_SELLING_ENABLED.getDefaultValue()).isEqualTo("false");
    assertThat(ConfigKey.SUBSCRIPTION_GOOGLE_SELLING_ENABLED.getDefaultValue()).isEqualTo("false");
    assertThat(ConfigKey.SUBSCRIPTION_APPLE_ALLOW_SANDBOX.getDefaultValue()).isEqualTo("false");
    assertThat(ConfigKey.SUBSCRIPTION_GOOGLE_ALLOW_TEST_PURCHASES.getDefaultValue()).isEqualTo("false");
    assertThat(ConfigKey.SUBSCRIPTION_APPLE_PRODUCT_IDS.getDefaultValue()).isEmpty();
    assertThat(ConfigKey.SUBSCRIPTION_GOOGLE_PRODUCT_IDS.getDefaultValue()).isEmpty();
    assertThat(ConfigKey.SUBSCRIPTION_GOOGLE_RTDN_PUSH_TOKEN.getValueType()).isEqualTo(ConfigValueType.SECRET);
    assertThat(ConfigKey.SUBSCRIPTION_APPLE_PRIVATE_KEY.getValueType()).isEqualTo(ConfigValueType.SECRET);
  }

  @Test
  @DisplayName("서비스 계정 JSON(약 2.4KB)은 저장되고, 일반 비밀값은 300자 제한 그대로다")
  void longSecretDocument_isAccepted() {
    String serviceAccountJson = "{\"private_key\":\"" + "A".repeat(2_400) + "\"}";

    ConfigValueCheck document = SystemConfigValueValidator.check(ConfigKey.SUBSCRIPTION_GOOGLE_SERVICE_ACCOUNT_JSON, serviceAccountJson);
    ConfigValueCheck shortSecret = SystemConfigValueValidator.check(ConfigKey.SUBSCRIPTION_GOOGLE_RTDN_PUSH_TOKEN, "A".repeat(301));

    assertThat(document.isValid()).isTrue();
    assertThat(shortSecret.isValid()).isFalse();
  }

  @Test
  @DisplayName("상품 ID 목록: 정리해서 받고, 허용 밖 문자는 거부한다")
  void productIdList_isValidated() {
    assertThat(SystemConfigValueValidator.check(ConfigKey.SUBSCRIPTION_APPLE_PRODUCT_IDS, " a.b_c , a.b_c,x-1 ").isValid()).isTrue();
    assertThat(SystemConfigValueValidator.check(ConfigKey.SUBSCRIPTION_APPLE_PRODUCT_IDS, "bad id").isValid()).isFalse();
  }
}
