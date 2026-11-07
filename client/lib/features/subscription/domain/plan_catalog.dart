import 'package:flutter/foundation.dart';

/// 구독 기간 2개: 1개월, 1년 (상품 id 는 AppConfig, 가격은 스토어)
enum PlanPeriod { monthly, yearly }

/// 무료 체험 기간 단위 (스토어 값 그대로: App Store 기간 단위 · Google Play ISO 8601 `P7D`)
enum PlanTrialUnit { day, week, month, year }

/// 스토어가 이 계정에 준다고 알린 무료 체험 (#1166): [unitCount] × [unit] (예 7일 · 1주)
@immutable
class PlanFreeTrial {
  const PlanFreeTrial({required this.unitCount, required this.unit});

  final int unitCount;
  final PlanTrialUnit unit;

  /// 체험이 끝나는 날 (오늘 시작 기준, 달·해는 달력으로 더함)
  DateTime endDateFrom(DateTime start) => switch (unit) {
    PlanTrialUnit.day => DateTime(start.year, start.month, start.day + unitCount),
    PlanTrialUnit.week => DateTime(start.year, start.month, start.day + unitCount * DateTime.daysPerWeek),
    PlanTrialUnit.month => DateTime(start.year, start.month + unitCount, start.day),
    PlanTrialUnit.year => DateTime(start.year + unitCount, start.month, start.day),
  };

  @override
  bool operator ==(Object other) =>
      other is PlanFreeTrial && other.unitCount == unitCount && other.unit == unit;

  @override
  int get hashCode => Object.hash(unitCount, unit);
}

/// 스토어에서 받은 상품 하나: 기간 · 상품 id · 스토어가 준 현지 가격 문자열 그대로 · 무료 체험
@immutable
class PlanOffer {
  const PlanOffer({
    required this.period,
    required this.productId,
    required this.priceLabel,
    this.freeTrial,
  });

  final PlanPeriod period;
  final String productId;

  /// `₩9,900` 처럼 스토어가 만든 문자열 (체험 뒤 갱신 가격). 앱이 다시 만들거나 반올림하지 않는다
  final String priceLabel;

  /// 스토어가 이 계정이 받을 수 있다고 알린 무료 체험. 대상 아님·스토어가 못 알려 줌·조회 실패 > null (체험을 약속하지 않음)
  final PlanFreeTrial? freeTrial;
}

/// 요금제 화면이 그릴 상품 목록 (기간 순: 1개월 > 1년). 스토어가 모르는 상품은 빠진다
@immutable
class PlanCatalog {
  const PlanCatalog(this.offers);

  final List<PlanOffer> offers;

  bool get hasOffers => offers.isNotEmpty;

  /// 무료 체험이 붙은 상품이 하나라도 있는가 (결제 안내에 체험 해지 문장을 더함)
  bool get hasAnyFreeTrial => offers.any((offer) => offer.freeTrial != null);

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
