import 'package:flutter/foundation.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';

import '../domain/plan_catalog.dart';

/// 스토어 무료 체험 읽기 (#1166): 스토어가 이 계정에 준다고 알린 체험만 [PlanFreeTrial] 로
///
/// 모르면 null — 체험을 약속하지 않는 쪽으로 기움 (적용 안 될 체험을 화면에 쓰지 않음)

/// App Store 체험 조회 최대 대기 (상품 가격 조회와 별개, 넘기면 체험 없이 보임)
const _appStoreTrialTimeout = Duration(seconds: 5);

// Google Play ISO 8601 기간 (`P7D` · `P1W` · `P1M` · `P1Y`)
final _isoPeriodPattern = RegExp(r'^P(\d+)([DWMY])$');

/// Google Play 혜택 하나 > 무료 체험 (첫 단계 0원 · 마지막 단계 = 기본 요금제 가격). 아니면 null
///
/// Play 는 계정이 받을 수 있는 혜택만 상품 조회에 실어 줌 > 혜택이 왔으면 체험 대상
PlanFreeTrial? googlePlayFreeTrialOf(
  GooglePlayProductDetails product, {
  required int basePriceMicros,
}) {
  final index = product.subscriptionIndex;
  final offers = product.productDetails.subscriptionOfferDetails;
  if (index == null || offers == null || index >= offers.length) return null;
  final offer = offers[index];
  final phases = offer.pricingPhases;
  // 기본 요금제(offerId 없음)·단계 하나뿐인 혜택은 체험 아님
  if (offer.offerId == null || phases.length < 2) return null;
  final trialPhase = phases.first;
  // 0원이 아닌 첫 단계(할인 혜택)·체험 뒤 가격이 기본과 다른 혜택은 고르지 않음 (표시 가격 = 실제 갱신 가격)
  if (trialPhase.priceAmountMicros != 0 || phases.last.priceAmountMicros != basePriceMicros) {
    return null;
  }
  return _parseIsoPeriod(trialPhase.billingPeriod, cycleCount: trialPhase.billingCycleCount);
}

/// Google Play 기본 요금제 가격 (마이크로 단위). 기본 요금제가 아니면 null
int? googlePlayBasePriceMicrosOf(GooglePlayProductDetails product) {
  final index = product.subscriptionIndex;
  final offers = product.productDetails.subscriptionOfferDetails;
  if (index == null || offers == null || index >= offers.length) return null;
  final offer = offers[index];
  if (offer.offerId != null || offer.pricingPhases.isEmpty) return null;
  return offer.pricingPhases.last.priceAmountMicros;
}

/// App Store 상품 id > 무료 체험: 체험 대상 확인(StoreKit 2) + 체험 기간(StoreKit 1 상품 정보)
///
/// 어느 하나라도 실패·시간 초과면 그 상품은 체험 없음 (가격 표시는 그대로)
Future<Map<String, PlanFreeTrial>> loadAppStoreFreeTrials(Set<String> productIds) async {
  try {
    return await _loadAppStoreFreeTrials(productIds).timeout(_appStoreTrialTimeout);
  } catch (error) {
    debugPrint('[plan trial] app store trial lookup failed : $error');
    return const {};
  }
}

Future<Map<String, PlanFreeTrial>> _loadAppStoreFreeTrials(Set<String> productIds) async {
  // StoreKit 2 상품 정보에는 체험 기간이 없어 StoreKit 1 상품 요청으로 읽음
  final response = await SKRequestMaker().startProductRequest(productIds.toList());
  final trials = <String, PlanFreeTrial>{};
  for (final product in response.products) {
    final trial = _appStoreFreeTrialOf(product.introductoryPrice);
    if (trial == null) continue;
    // 이미 체험·구독한 계정이면 Apple 이 체험을 주지 않음 > 대상일 때만
    if (!InAppPurchaseStoreKitPlatform.isStoreKit2Enabled) continue;
    if (!await SK2Product.isIntroductoryOfferEligible(product.productIdentifier)) continue;
    trials[product.productIdentifier] = trial;
  }
  return trials;
}

/// App Store 소개 혜택 > 무료 체험 (결제 방식 freeTrial 만). 단계 길이 × 단계 수
PlanFreeTrial? _appStoreFreeTrialOf(SKProductDiscountWrapper? introductoryOffer) {
  if (introductoryOffer == null) return null;
  if (introductoryOffer.paymentMode != SKProductDiscountPaymentMode.freeTrail) return null;
  final period = introductoryOffer.subscriptionPeriod;
  final unitCount = period.numberOfUnits * introductoryOffer.numberOfPeriods;
  if (unitCount <= 0) return null;
  return PlanFreeTrial(
    unitCount: unitCount,
    unit: switch (period.unit) {
      SKSubscriptionPeriodUnit.day => PlanTrialUnit.day,
      SKSubscriptionPeriodUnit.week => PlanTrialUnit.week,
      SKSubscriptionPeriodUnit.month => PlanTrialUnit.month,
      SKSubscriptionPeriodUnit.year => PlanTrialUnit.year,
    },
  );
}

/// `P7D` + 반복 횟수 > 체험 기간. 모르는 모양이면 null
PlanFreeTrial? _parseIsoPeriod(String isoPeriod, {required int cycleCount}) {
  final match = _isoPeriodPattern.firstMatch(isoPeriod);
  final count = int.tryParse(match?.group(1) ?? '');
  if (match == null || count == null) return null;
  final unitCount = count * (cycleCount < 1 ? 1 : cycleCount);
  if (unitCount <= 0) return null;
  return PlanFreeTrial(
    unitCount: unitCount,
    unit: switch (match.group(2)) {
      'D' => PlanTrialUnit.day,
      'W' => PlanTrialUnit.week,
      'M' => PlanTrialUnit.month,
      _ => PlanTrialUnit.year,
    },
  );
}
