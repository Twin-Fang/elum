package com.chuseok22.elumserver.credit.application.service.purchase;

import com.chuseok22.elumserver.credit.application.dto.response.CreditPacksResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/// 꾸러미 목록 응답: 판매가 꺼져 있으면 isSaleEnabled=false 와 빈 목록
@Service
@RequiredArgsConstructor
public class CreditPackQueryService {

  private final CreditPackCatalog packCatalog;

  public CreditPacksResponse getPacks() {
    if (!packCatalog.isSaleEnabled()) {
      return CreditPacksResponse.saleOff();
    }
    String popularProductId = packCatalog.popularProductId();
    return new CreditPacksResponse(true, packCatalog.packs().stream()
      .map(pack -> new CreditPacksResponse.Pack(pack.productId(), pack.credits(), pack.productId().equals(popularProductId)))
      .toList());
  }
}
