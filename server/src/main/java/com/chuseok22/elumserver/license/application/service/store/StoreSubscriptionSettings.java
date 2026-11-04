package com.chuseok22.elumserver.license.application.service.store;

import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigValueValidator;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 스토어 구독 설정 읽기: 켜기, 앱 식별값, 허용 상품, 테스트 결제 허용, 스토어 API 인증값
 * 설정을 못 읽으면 꺼진 것으로 (막는 쪽, 돈이 걸린 기능이라)
 */
@Component
@RequiredArgsConstructor
public class StoreSubscriptionSettings {

  private final SystemConfigService systemConfigService;

  public boolean isAppleEnabled() {
    return readFlagOrFalse(ConfigKey.SUBSCRIPTION_APPLE_ENABLED);
  }

  public boolean isGoogleEnabled() {
    return readFlagOrFalse(ConfigKey.SUBSCRIPTION_GOOGLE_ENABLED);
  }

  public boolean isAppleSandboxAllowed() {
    return readFlagOrFalse(ConfigKey.SUBSCRIPTION_APPLE_ALLOW_SANDBOX);
  }

  public boolean isGoogleTestPurchaseAllowed() {
    return readFlagOrFalse(ConfigKey.SUBSCRIPTION_GOOGLE_ALLOW_TEST_PURCHASES);
  }

  public String appleBundleId() {
    return systemConfigService.getString(ConfigKey.SUBSCRIPTION_APPLE_BUNDLE_ID).trim();
  }

  /// App Store 앱 ID (숫자), 비었거나 숫자가 아니면 null
  public Long appleAppAppleId() {
    String text = systemConfigService.getString(ConfigKey.SUBSCRIPTION_APPLE_APP_APPLE_ID).trim();
    try {
      return text.isEmpty() ? null : Long.parseLong(text);
    } catch (NumberFormatException e) {
      return null;
    }
  }

  public Set<String> appleProductIds() {
    return productIdsOf(ConfigKey.SUBSCRIPTION_APPLE_PRODUCT_IDS);
  }

  public String googlePackageName() {
    return systemConfigService.getString(ConfigKey.SUBSCRIPTION_GOOGLE_PACKAGE_NAME).trim();
  }

  public Set<String> googleProductIds() {
    return productIdsOf(ConfigKey.SUBSCRIPTION_GOOGLE_PRODUCT_IDS);
  }

  /// App Store Server API 인증값 3개, 하나라도 비면 null (서명 검증만으로 처리)
  public AppleServerApiCredentials appleServerApiCredentials() {
    String issuerId = systemConfigService.getSecret(ConfigKey.SUBSCRIPTION_APPLE_ISSUER_ID).trim();
    String keyId = systemConfigService.getSecret(ConfigKey.SUBSCRIPTION_APPLE_KEY_ID).trim();
    String privateKey = systemConfigService.getSecret(ConfigKey.SUBSCRIPTION_APPLE_PRIVATE_KEY).trim();
    if (issuerId.isEmpty() || keyId.isEmpty() || privateKey.isEmpty()) {
      return null;
    }
    return new AppleServerApiCredentials(issuerId, keyId, privateKey);
  }

  /// 서비스 계정 JSON, 없으면 빈 문자열
  public String googleServiceAccountJson() {
    return systemConfigService.getSecret(ConfigKey.SUBSCRIPTION_GOOGLE_SERVICE_ACCOUNT_JSON).trim();
  }

  /// Pub/Sub 푸시 주소의 token 값, 없으면 빈 문자열 (빈 값이면 알림 전부 거절)
  public String googleRtdnPushToken() {
    return systemConfigService.getSecret(ConfigKey.SUBSCRIPTION_GOOGLE_RTDN_PUSH_TOKEN).trim();
  }

  private boolean readFlagOrFalse(ConfigKey key) {
    try {
      return systemConfigService.getBoolean(key);
    } catch (RuntimeException e) {
      return false;
    }
  }

  private Set<String> productIdsOf(ConfigKey key) {
    return Set.copyOf(SystemConfigValueValidator.splitListItems(systemConfigService.getString(key)));
  }

  /**
   * App Store Server API 인증값 (App Store Connect 앱 내 구입 키)
   *
   * @param privateKeyPem .p8 내용 (BEGIN/END 줄·줄바꿈이 빠졌을 수 있음)
   */
  public record AppleServerApiCredentials(String issuerId, String keyId, String privateKeyPem) {

    // 로그·예외 메시지에 키가 찍히지 않게
    @Override
    public String toString() {
      return "AppleServerApiCredentials[keyId=" + StoreLogValues.mask(keyId) + "]";
    }
  }
}
