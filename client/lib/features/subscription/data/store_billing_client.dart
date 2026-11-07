import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../domain/plan_catalog.dart';
import '../domain/store_purchase_update.dart';
import 'store_free_trial.dart';

/// 스토어 상품을 못 불러옴 (스토어 연결 불가 · 상품 없음 · 조회 오류)
class StoreCatalogException implements Exception {
  const StoreCatalogException(this.reason);

  /// 로그용 원인 (`unavailable` · `query:<코드>` · `empty`)
  final String reason;

  @override
  String toString() => 'StoreCatalogException($reason)';
}

/// App Store · Google Play 결제 창구: 상품 조회, 결제창, 구매 소식, 거래 마무리, 복원
///
/// iOS 는 StoreKit 2(패키지 기본) > 구매 증빙이 거래 JWS. Android 는 Play Billing > 구매 토큰
/// 패키지 타입은 여기서 [StorePurchaseUpdate] 로 바꿔 응용 계층에 흘리지 않음
class StoreBillingClient {
  StoreBillingClient({InAppPurchase? store}) : _injectedStore = store;

  final InAppPurchase? _injectedStore;

  // 플랫폼 채널을 처음 쓸 때 만듦 (결제 꺼진 빌드·테스트에서 채널을 건드리지 않게)
  InAppPurchase get _store => _injectedStore ?? InAppPurchase.instance;

  /// 상품 id > 스토어 상품 (결제창에 그대로 넘김)
  final Map<String, ProductDetails> _productsById = {};

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  StorePlatform get platform =>
      _isAndroid ? StorePlatform.googlePlay : StorePlatform.appStore;

  /// 스토어 구매 소식 (결제·허락 대기·갱신·복원). 처음 구독할 때 iOS 거래 감시가 시작됨
  Stream<List<StorePurchaseUpdate>> get purchaseUpdates => _store.purchaseStream
      .map((purchases) => purchases.map(_toUpdate).toList());

  /// 상품 불러오기: 스토어 연결 확인 > 조회 > 기간별 1개 (가격 = 기본 요금제 갱신 가격) + 무료 체험 (#1166)
  Future<PlanCatalog> loadCatalog(Map<PlanPeriod, String> productIdByPeriod) async {
    if (!await _store.isAvailable()) {
      throw const StoreCatalogException('unavailable');
    }
    final ids = productIdByPeriod.values.where((id) => id.isNotEmpty).toSet();
    final response = await _store.queryProductDetails(ids);
    final error = response.error;
    if (error != null) throw StoreCatalogException('query:${error.code}');

    // iOS 체험은 상품 정보에 없어 따로 조회 (실패하면 체험 없이 가격만)
    final appStoreTrials = _isAndroid ? const <String, PlanFreeTrial>{} : await loadAppStoreFreeTrials(ids);
    final offers = <PlanOffer>[];
    for (final MapEntry(key: period, value: productId) in productIdByPeriod.entries) {
      final choice = _pickPurchaseChoice(response.productDetails, productId);
      if (choice == null) continue;
      _productsById[productId] = choice.purchaseProduct;
      offers.add(
        PlanOffer(
          period: period,
          productId: productId,
          priceLabel: choice.priceLabel,
          freeTrial: _isAndroid ? choice.freeTrial : appStoreTrials[productId],
          rawPrice: choice.rawPrice,
          currencyCode: choice.currencyCode,
        ),
      );
    }
    if (offers.isEmpty) throw const StoreCatalogException('empty');
    offers.sort((a, b) => a.period.index.compareTo(b.period.index));
    return PlanCatalog(offers);
  }

  /// 같은 상품 id 중 결제할 것 + 표시 가격 + (Android) 무료 체험
  ///
  /// Android 는 구독 하나가 요금제·혜택마다 따로 오고, 계정이 받을 수 있는 혜택만 옴 >
  /// 가격은 혜택 없는 기본 요금제(offerId 없음), 결제는 무료 체험 혜택이 있으면 그 혜택 토큰으로 (없으면 기본)
  _PurchaseChoice? _pickPurchaseChoice(List<ProductDetails> products, String productId) {
    final candidates = products.where((p) => p.id == productId).toList();
    if (candidates.isEmpty) return null;
    if (!_isAndroid) {
      final product = candidates.first;
      return _PurchaseChoice.priced(product, priceProduct: product);
    }
    final googleCandidates = candidates.whereType<GooglePlayProductDetails>().toList();
    GooglePlayProductDetails? basePlan;
    int? basePriceMicros;
    for (final product in googleCandidates) {
      basePriceMicros = googlePlayBasePriceMicrosOf(product);
      if (basePriceMicros != null) {
        basePlan = product;
        break;
      }
    }
    // 기본 요금제를 못 찾은 Android 상품은 가격이 다를 수 있음 > 팔지 않음
    if (basePlan == null || basePriceMicros == null) return null;
    for (final product in googleCandidates) {
      final freeTrial = googlePlayFreeTrialOf(product, basePriceMicros: basePriceMicros);
      if (freeTrial != null) {
        return _PurchaseChoice.priced(product, priceProduct: basePlan, freeTrial: freeTrial);
      }
    }
    return _PurchaseChoice.priced(basePlan, priceProduct: basePlan);
  }

  /// 결제창 열기. [accountToken] 은 보호자 회원 id(UUID) > Apple appAccountToken · Google obfuscatedAccountId
  ///
  /// 결과는 [purchaseUpdates] 로 옴. 결제창을 못 띄웠으면 false, 상품을 아직 안 불러왔으면 [StateError]
  Future<bool> buy({required String productId, required String accountToken}) async {
    final product = _productsById[productId];
    if (product == null) throw StateError('product not loaded: $productId');
    return _store.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: product,
        applicationUserName: accountToken,
      ),
    );
  }

  /// 거래 마무리: Apple finish · Google acknowledge (이미 됐으면 패키지가 건너뜀)
  Future<void> finish(StorePurchaseUpdate update) async {
    final purchase = update.handle;
    if (purchase is! PurchaseDetails) return;
    // Apple 은 거래 id 가 있어야 finish 가능 (복원 소식도 같은 거래면 한 번 더 finish 해도 무해)
    if (update.platform == StorePlatform.appStore && update.transactionId == null) {
      return;
    }
    await _store.completePurchase(purchase);
  }

  /// 구매 복원: 결과는 [purchaseUpdates] 로 `restored` 가 옴 (되찾을 것이 없으면 아무것도 안 옴)
  Future<void> restore() => _store.restorePurchases();

  /// Android: 아직 acknowledge 안 된 지난 구매 (서버 확인이 끊긴 결제를 앱 시작 때 다시 확인)
  ///
  /// iOS 는 끝나지 않은 거래를 스토어가 앱 시작 때 [purchaseUpdates] 로 다시 보내므로 빈 목록
  Future<List<StorePurchaseUpdate>> unsettledPastPurchases() async {
    if (!_isAndroid) return const [];
    final addition = _store.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases();
    return [
      for (final purchase in response.pastPurchases)
        if (!purchase.billingClientPurchase.isAcknowledged) _toUpdate(purchase),
    ];
  }

  StorePurchaseUpdate _toUpdate(PurchaseDetails purchase) {
    final isGoogle = purchase is GooglePlayPurchaseDetails;
    return StorePurchaseUpdate(
      platform: isGoogle ? StorePlatform.googlePlay : StorePlatform.appStore,
      status: switch (purchase.status) {
        PurchaseStatus.pending => StorePurchaseStatus.pending,
        PurchaseStatus.purchased => StorePurchaseStatus.purchased,
        PurchaseStatus.restored => StorePurchaseStatus.restored,
        PurchaseStatus.canceled => StorePurchaseStatus.canceled,
        PurchaseStatus.error => StorePurchaseStatus.error,
      },
      productId: purchase.productID,
      verificationToken: purchase.verificationData.serverVerificationData,
      transactionId: isGoogle ? null : purchase.purchaseID,
      isAcknowledged: isGoogle && purchase.billingClientPurchase.isAcknowledged,
      errorCode: purchase.error?.code,
      handle: purchase,
    );
  }
}

/// 상품 하나에서 고른 결제 대상 · 표시 가격(문자열 · 숫자 · 통화) · 무료 체험
class _PurchaseChoice {
  const _PurchaseChoice({
    required this.purchaseProduct,
    required this.priceLabel,
    this.freeTrial,
    this.rawPrice,
    this.currencyCode,
  });

  /// 결제 대상 + 가격을 읽을 상품 (Android 는 기본 요금제 가격: 체험 혜택 상품의 첫 가격은 0)
  factory _PurchaseChoice.priced(
    ProductDetails purchaseProduct, {
    required ProductDetails priceProduct,
    PlanFreeTrial? freeTrial,
  }) => _PurchaseChoice(
    purchaseProduct: purchaseProduct,
    priceLabel: priceProduct.price,
    freeTrial: freeTrial,
    rawPrice: priceProduct.rawPrice,
    currencyCode: priceProduct.currencyCode.isEmpty ? null : priceProduct.currencyCode,
  );

  /// 결제창에 넘길 상품 (Android 는 이 혜택의 토큰으로 결제)
  final ProductDetails purchaseProduct;

  /// 체험 뒤 갱신 가격 (스토어 문자열)
  final String priceLabel;
  final PlanFreeTrial? freeTrial;
  final double? rawPrice;
  final String? currencyCode;
}

final storeBillingClientProvider = Provider<StoreBillingClient>(
  (ref) => StoreBillingClient(),
);
