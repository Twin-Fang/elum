import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../member/application/member_providers.dart';
import '../data/store_billing_client.dart';
import '../domain/plan_catalog.dart';
import '../domain/plan_error_code.dart';
import '../domain/plan_purchase_state.dart';
import '../domain/store_purchase_update.dart';
import '../domain/store_verification.dart';
import 'plan_purchase_notifier.dart';
import 'plan_store_catalog.dart';
import 'store_purchase_verifier.dart';

/// 구매 복원 결과 3개: 되찾음, 되찾을 것 없음, 실패
enum PlanRestoreResult { restored, nothingToRestore, failed }

/// 구매 복원 결과 + 실패 원인
class PlanRestoreOutcome {
  const PlanRestoreOutcome(this.result, {this.failure});

  final PlanRestoreResult result;
  final Object? failure;
}

/// 스토어 구매 > 서버 확인 > 거래 마무리를 맡는 한 곳 (결제·복원·앱 시작 때 남은 거래)
///
/// 돈 규칙 4개
/// - Pro 는 서버만 켬. 앱은 서버 200 결과를 화면에 옮길 뿐
/// - Apple finish 는 서버가 처리 끝냄(ACTIVE·INACTIVE) 뒤에만. PENDING·실패면 남겨 둠 > 스토어가 다음 실행에 다시 보냄
/// - Google acknowledge 는 서버가 함. 앱은 ACTIVE 를 받은 뒤 남은 경우만 한 번 더 (서버 재시도 전 3일 자동 환불 방지)
/// - 같은 증빙은 동시에 한 번만 확인 (스토어가 같은 거래를 겹쳐 보내도 요청 1번)
///
/// 구매 한 건 서버 확인·거래 마무리는 [StorePurchaseVerifier]
class StorePurchaseCoordinator {
  StorePurchaseCoordinator(this._ref) : _verifier = StorePurchaseVerifier(_ref);

  final Ref _ref;
  final StorePurchaseVerifier _verifier;

  StreamSubscription<List<StorePurchaseUpdate>>? _purchaseSubscription;

  /// 복원 요청 뒤 스토어가 복원 소식을 다 보낼 때까지 기다리는 시간
  static const _restoreSettleDelay = Duration(seconds: 2);

  /// StoreKit 2: 같은 상품에 끝나지 않은 거래가 있어 새 결제를 막음 (in_app_purchase_storekit)
  static const _duplicateTransactionCode = 'storekit_duplicate_product_object';

  StoreBillingClient get _store => _ref.read(storeBillingClientProvider);
  PlanPurchaseNotifier get _flow => _ref.read(planPurchaseStateProvider.notifier);

  /// 구매 소식 듣기 시작 + Android 미확인 구매 다시 확인 (앱 시작 · 요금제 화면 열 때, 여러 번 불러도 1번)
  ///
  /// 보호자 기기 + 판매 스위치 켜짐일 때만. 이룸이 기기는 스토어를 건드리지 않음
  Future<void> start() async {
    if (_purchaseSubscription != null) return;
    if (!_ref.read(isPlanStoreEnabledProvider)) return;
    _purchaseSubscription = _store.purchaseUpdates.listen(
      (updates) => unawaited(_onPurchaseUpdates(updates)),
      onError: (Object error, StackTrace stack) =>
          AppLogger.error('[plan purchase] stream failed', error, stack),
    );
    await _recheckUnsettledPurchases();
  }

  /// 결제: 흐름 시작 > 회원 id 확인 > 결제창 (결과는 구매 소식으로). PIN 확인은 부르는 쪽이 끝냄
  Future<void> buy(PlanOffer offer) async {
    if (!_flow.apply(const PlanPurchaseEvent.purchaseRequested())) return;
    await start();
    final memberId = await _readMemberId();
    if (!isPurchaseAccountToken(memberId)) {
      AppLogger.info('[plan purchase] rejected : member id is not a uuid');
      _flow.apply(
        const PlanPurchaseEvent.storeFailed(null, failureCode: PlanErrorCode.account),
      );
      return;
    }
    try {
      final isLaunched = await _store.buy(
        productId: offer.productId,
        accountToken: memberId!,
      );
      if (!isLaunched) {
        _flow.apply(const PlanPurchaseEvent.storeFailed(null));
      }
    } on PlatformException catch (error, stack) {
      if (error.code == _duplicateTransactionCode) {
        // 이전 결제가 확인을 기다림 > 다시 결제시키지 않고 그 거래를 다시 확인
        AppLogger.info('[plan purchase] unfinished transaction exists : recheck');
        await retryVerification();
        return;
      }
      AppLogger.error('[plan purchase] buy failed', error, stack, {'code': error.code});
      _flow.apply(PlanPurchaseEvent.storeFailed(error));
    } catch (error, stack) {
      AppLogger.error('[plan purchase] buy failed', error, stack);
      _flow.apply(PlanPurchaseEvent.storeFailed(error));
    }
  }

  /// `다시 확인`: 남은 구매를 다시 보냄. 기억한 구매가 없으면(앱을 다시 켬 등) 스토어 복원으로 찾아 확인
  Future<void> retryVerification() async {
    final unsettled = _verifier.lastUnsettledPurchase;
    if (unsettled != null) {
      await _verifier.verify(unsettled);
      return;
    }
    _flow.apply(const PlanPurchaseEvent.verificationStarted());
    final outcome = await restore();
    switch (outcome.result) {
      case PlanRestoreResult.restored:
        _flow.apply(const PlanPurchaseEvent.verificationFinished(StoreVerification.active));
      case PlanRestoreResult.nothingToRestore:
        _flow.apply(const PlanPurchaseEvent.verificationFinished(StoreVerification.pending));
      case PlanRestoreResult.failed:
        _flow.apply(
          PlanPurchaseEvent.verificationFailed(
            outcome.failure,
            isRetryable: StorePurchaseVerifier.isRetryable(outcome.failure),
          ),
        );
    }
  }

  /// 구매 복원: 스토어 복원 > 복원 소식 서버 확인 대기 > 회원 정보 다시 받아 Pro 인지 확인
  Future<PlanRestoreOutcome> restore() async {
    await start();
    _verifier.beginRestore();
    try {
      await _store.restore();
      await Future<void>.delayed(_restoreSettleDelay);
      await _verifier.waitForVerifications();
      final failure = _verifier.restoreFailure;
      final member = await _ref.refresh(memberProvider.future);
      if (member?.entitlements.isPro == true) {
        return const PlanRestoreOutcome(PlanRestoreResult.restored);
      }
      if (failure != null) {
        return PlanRestoreOutcome(PlanRestoreResult.failed, failure: failure);
      }
      return const PlanRestoreOutcome(PlanRestoreResult.nothingToRestore);
    } catch (error, stack) {
      AppLogger.error('[plan restore] failed', error, stack);
      return PlanRestoreOutcome(PlanRestoreResult.failed, failure: error);
    } finally {
      _verifier.endRestore();
    }
  }

  /// 구매 소식 처리 (순서대로 한 건씩)
  Future<void> _onPurchaseUpdates(List<StorePurchaseUpdate> updates) async {
    for (final update in updates) {
      AppLogger.info(
        '[plan purchase] store update : ${update.platform.name} ${update.status.name}',
      );
      switch (update.status) {
        case StorePurchaseStatus.pending:
          _flow.apply(const PlanPurchaseEvent.storePending());
        case StorePurchaseStatus.canceled:
          _flow.apply(const PlanPurchaseEvent.storeCanceled());
        case StorePurchaseStatus.error:
          _flow.apply(PlanPurchaseEvent.storeFailed(update.errorCode));
        case StorePurchaseStatus.purchased:
        case StorePurchaseStatus.restored:
          await _verifier.verify(update);
      }
    }
  }

  /// Android: acknowledge 안 된 지난 구매를 조용히 다시 확인 (서버 확인이 끊긴 결제)
  Future<void> _recheckUnsettledPurchases() async {
    if (!_verifier.canCallServer) return;
    try {
      final purchases = await _store.unsettledPastPurchases();
      for (final purchase in purchases) {
        if (purchase.status == StorePurchaseStatus.purchased) await _verifier.verify(purchase);
      }
    } catch (error, stack) {
      AppLogger.error('[plan purchase] past purchases failed', error, stack);
    }
  }

  Future<String?> _readMemberId() async {
    final cached = _ref.read(memberProvider).value?.id;
    if (cached != null) return cached;
    try {
      return (await _ref.read(memberProvider.future))?.id;
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    unawaited(_purchaseSubscription?.cancel());
    _purchaseSubscription = null;
  }
}

final storePurchaseCoordinatorProvider = Provider<StorePurchaseCoordinator>((ref) {
  final coordinator = StorePurchaseCoordinator(ref);
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
