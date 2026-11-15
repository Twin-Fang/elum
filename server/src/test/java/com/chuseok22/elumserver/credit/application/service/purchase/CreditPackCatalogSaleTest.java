package com.chuseok22.elumserver.credit.application.service.purchase;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 꾸러미 판매 스위치: 전체 OR 스토어별, 옛 앱(스토어 모름)은 전체만 (#1427)
 */
class CreditPackCatalogSaleTest {

  private final SystemConfigService config = mock(SystemConfigService.class);
  private final CreditPackCatalog catalog = new CreditPackCatalog(config);

  @Test
  @DisplayName("Google 만 켜면 Android 에만 팔고 iOS·옛 앱에는 꾸러미가 안 보인다")
  void googleOnly_sellsOnAndroidOnly() {
    when(config.getBoolean(ConfigKey.CREDIT_PACK_SALE_ENABLED)).thenReturn(false);
    when(config.getBoolean(ConfigKey.CREDIT_PACK_APPLE_SALE_ENABLED)).thenReturn(false);
    when(config.getBoolean(ConfigKey.CREDIT_PACK_GOOGLE_SALE_ENABLED)).thenReturn(true);

    assertThat(catalog.isSaleEnabled(SubscriptionSource.GOOGLE_IAP)).isTrue();
    assertThat(catalog.isSaleEnabled(SubscriptionSource.APPLE_IAP)).isFalse();
    assertThat(catalog.isSaleEnabled(null)).isFalse();
  }

  @Test
  @DisplayName("스위치를 못 읽으면 판매 꺼짐 — 설정 장애로 결제가 열리지 않는다")
  void unreadableFlag_isOff() {
    when(config.getBoolean(ConfigKey.CREDIT_PACK_SALE_ENABLED)).thenThrow(new IllegalStateException("db"));
    when(config.getBoolean(ConfigKey.CREDIT_PACK_GOOGLE_SALE_ENABLED)).thenThrow(new IllegalStateException("db"));

    assertThat(catalog.isSaleEnabled(SubscriptionSource.GOOGLE_IAP)).isFalse();
  }
}
