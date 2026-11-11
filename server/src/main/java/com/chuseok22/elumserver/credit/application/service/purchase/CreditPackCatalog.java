package com.chuseok22.elumserver.credit.application.service.purchase;

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

  public boolean isSaleEnabled() {
    try {
      return config.getBoolean(ConfigKey.CREDIT_PACK_SALE_ENABLED);
    } catch (RuntimeException e) {
      log.warn("[credit pack] sale flag unreadable, treated as off : {}", e.getClass().getSimpleName());
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
