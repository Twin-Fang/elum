import 'package:flutter/foundation.dart';

/// 구독 기간 2개: 1개월, 1년 (상품 id 는 AppConfig, 가격은 스토어)
enum PlanPeriod { monthly, yearly }

/// 스토어에서 받은 상품 하나: 기간 · 상품 id · 스토어가 준 현지 가격 문자열 그대로
@immutable
class PlanOffer {
  const PlanOffer({
    required this.period,
    required this.productId,
    required this.priceLabel,
  });

  final PlanPeriod period;
  final String productId;

  /// `₩9,900` 처럼 스토어가 만든 문자열. 앱이 다시 만들거나 반올림하지 않는다
  final String priceLabel;
}

/// 요금제 화면이 그릴 상품 목록 (기간 순: 1개월 > 1년). 스토어가 모르는 상품은 빠진다
@immutable
class PlanCatalog {
  const PlanCatalog(this.offers);

  final List<PlanOffer> offers;

  bool get hasOffers => offers.isNotEmpty;

  PlanOffer? offerFor(PlanPeriod period) {
    for (final offer in offers) {
      if (offer.period == period) return offer;
    }
    return null;
  }

  /// 상품 id > 기간 (결제 확인 응답의 상품이 어느 기간인지)
  PlanPeriod? periodOf(String? productId) {
    for (final offer in offers) {
      if (offer.productId == productId) return offer.period;
    }
    return null;
  }
}
