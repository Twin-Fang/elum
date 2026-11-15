package com.chuseok22.elumserver.credit.application.service.purchase;

import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.core.CreditPackListFormat;
import com.chuseok22.elumserver.systemconfig.core.CreditPackListFormat.Pack;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * 크레딧 꾸러미 설정 읽기: 판매 켜짐, 상품 목록(상품 ID > 개수), 인기 상품
 * 설정을 못 읽으면 판매 꺼짐 (돈이 걸린 기능이라 막는 쪽)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class CreditPackCatalog {

  private final SystemConfigService config;

  /// 판매 켜짐: 전체 스위치 OR 스토어별 스위치. [store] 가 null(옛 앱, 플랫폼 모름)이면 전체 스위치만 봄 (#1427)
  public boolean isSaleEnabled(SubscriptionSource store) {
    if (readFlag(ConfigKey.CREDIT_PACK_SALE_ENABLED)) {
      return true;
    }
    if (store == null) {
      return false;
    }
    return switch (store) {
      case APPLE_IAP -> readFlag(ConfigKey.CREDIT_PACK_APPLE_SALE_ENABLED);
      case GOOGLE_IAP -> readFlag(ConfigKey.CREDIT_PACK_GOOGLE_SALE_ENABLED);
      default -> false;
    };
  }

  /// 스위치 읽기 실패는 꺼짐 (돈이 걸린 기능이라 막는 쪽)
  private boolean readFlag(ConfigKey key) {
    try {
      return config.getBoolean(key);
    } catch (RuntimeException e) {
      log.warn("[credit pack] sale flag unreadable, treated as off : key={}, {}", key, e.getClass().getSimpleName());
      return false;
    }
  }

  /// 설정 순서대로의 꾸러미 (형식이 틀린 항목은 빠짐)
  public List<Pack> packs() {
    return CreditPackListFormat.parse(config.getString(ConfigKey.CREDIT_PACK_PRODUCTS));
  }

  public Optional<Pack> findPack(String productId) {
    return packs().stream().filter(pack -> pack.productId().equals(productId)).findFirst();
  }

  public String popularProductId() {
    return config.getString(ConfigKey.CREDIT_PACK_POPULAR_PRODUCT_ID).trim();
  }
}
