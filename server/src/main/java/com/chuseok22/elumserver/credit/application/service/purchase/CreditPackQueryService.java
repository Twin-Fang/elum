package com.chuseok22.elumserver.credit.application.service.purchase;

import com.chuseok22.elumserver.credit.application.dto.response.CreditPacksResponse;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/// 꾸러미 목록 응답: 판매가 꺼져 있으면 isSaleEnabled=false 와 빈 목록. [store] 는 요청한 앱의 스토어 (모르면 null)
@Service
@RequiredArgsConstructor
public class CreditPackQueryService {

  private final CreditPackCatalog packCatalog;

  public CreditPacksResponse getPacks(SubscriptionSource store) {
    if (!packCatalog.isSaleEnabled(store)) {
      return CreditPacksResponse.saleOff();
    }
    String popularProductId = packCatalog.popularProductId();
    return new CreditPacksResponse(true, packCatalog.packs().stream()
      .map(pack -> new CreditPacksResponse.Pack(pack.productId(), pack.credits(), pack.productId().equals(popularProductId)))
      .toList());
  }
}
