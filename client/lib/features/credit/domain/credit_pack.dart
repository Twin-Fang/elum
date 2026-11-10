import 'package:flutter/foundation.dart';

/// 서버가 파는 크레딧 꾸러미 한 개 — `GET /api/credits/packs` 의 `packs[]`
@immutable
class CreditPack {
  const CreditPack({required this.productId, required this.credits, this.isPopular = false});

  final String productId;
  final int credits;
  final bool isPopular;

  static CreditPack? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final productId = raw['productId'];
    final credits = raw['credits'];
    if (productId is! String || productId.isEmpty || credits is! num || credits <= 0) return null;
    return CreditPack(productId: productId, credits: credits.toInt(), isPopular: raw['isPopular'] == true);
  }
}

/// 꾸러미 판매 목록: 판매 스위치 + 꾸러미들 (개수 적은 순)
@immutable
class CreditPackSale {
  const CreditPackSale({required this.isSaleEnabled, required this.packs});

  static const closed = CreditPackSale(isSaleEnabled: false, packs: []);

  final bool isSaleEnabled;
  final List<CreditPack> packs;

  /// 팔 수 있는가: 스위치 켜짐 + 꾸러미 있음
  bool get hasPacksToSell => isSaleEnabled && packs.isNotEmpty;

  /// 모양이 다르면 판매 꺼짐으로 본다 (구역을 숨김)
  static CreditPackSale parse(Object? raw) {
    if (raw is! Map) return closed;
    final rawPacks = raw['packs'];
    final packs = rawPacks is List ? rawPacks.map(CreditPack.tryParse).whereType<CreditPack>().toList() : <CreditPack>[];
    packs.sort((a, b) => a.credits.compareTo(b.credits));
    return CreditPackSale(isSaleEnabled: raw['isSaleEnabled'] == true, packs: packs);
  }
}

/// 스토어가 준 상품 값 (문자열은 스토어 그대로, 숫자·통화는 할인율 계산용)
@immutable
class CreditPackStorePrice {
  const CreditPackStorePrice({required this.label, this.rawPrice, this.currencyCode});

  final String label;
  final double? rawPrice;
  final String? currencyCode;
}

/// 화면이 그릴 꾸러미 한 칸: 꾸러미 + 스토어 값 + 할인
@immutable
class CreditPackOffer {
  const CreditPackOffer({
    required this.pack,
    required this.price,
    this.discountPercent,
    this.listPrice,
  });

  final CreditPack pack;
  final CreditPackStorePrice price;

  /// 가장 작은 꾸러미 개당 값 대비 할인율(내림). 1% 미만이면 null
  final int? discountPercent;

  /// 원래 값 = 기준 개당 값 × 개수 (표시용 숫자, 문자열은 화면이 통화 모양으로)
  final double? listPrice;
}

/// 꾸러미 + 스토어 값 > 칸 목록: 가장 작은 꾸러미의 개당 값이 기준
///
/// 스토어 값을 못 받은 꾸러미는 뺀다 (값 없이 팔지 않음). 값 숫자를 모르면 할인 없이 값만.
List<CreditPackOffer> buildCreditPackOffers(List<CreditPack> packs, Map<String, CreditPackStorePrice> priceByProductId) {
  final sellable = [for (final pack in packs) if (priceByProductId[pack.productId] != null) pack];
  if (sellable.isEmpty) return const [];
  final basePack = sellable.first;
  final baseRaw = priceByProductId[basePack.productId]?.rawPrice;
  final baseUnitPrice = baseRaw == null ? null : baseRaw / basePack.credits;
  return [
    for (final pack in sellable)
      _offerOf(pack, priceByProductId[pack.productId]!, isBase: pack == basePack, baseUnitPrice: baseUnitPrice),
  ];
}

CreditPackOffer _offerOf(
  CreditPack pack,
  CreditPackStorePrice price, {
  required bool isBase,
  required double? baseUnitPrice,
}) {
  final raw = price.rawPrice;
  if (isBase || baseUnitPrice == null || raw == null || raw <= 0) return CreditPackOffer(pack: pack, price: price);
  final listPrice = baseUnitPrice * pack.credits;
  final percent = ((1 - raw / listPrice) * 100).floor();
  if (percent < 1) return CreditPackOffer(pack: pack, price: price);
  return CreditPackOffer(pack: pack, price: price, discountPercent: percent, listPrice: listPrice);
}
