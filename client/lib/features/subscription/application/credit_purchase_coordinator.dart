import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/storage/local_storage.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../credit/application/credit_pack_service.dart';
import '../../credit/application/credit_summary_refresh.dart';
import '../../credit/domain/credit_pack.dart';
import '../../credit/domain/credit_purchase.dart';
import '../../member/application/member_providers.dart';
import '../data/store_billing_client.dart';
import '../domain/store_purchase_update.dart';
import 'credit_purchase_notifier.dart';
import 'store_purchase_coordinator.dart';

/// 크레딧 꾸러미 구매: 스토어 결제 > 서버 확인 > 거래 마무리 > 잔액 다시 받기 (소모성 상품)
///
/// 구독과 같은 스토어 구매 소식을 나눠 받음: [StorePurchaseCoordinator] 가 상품 id 로 갈라 여기로 보냄.
/// 돈 규칙 3개
/// - 크레딧은 서버만 넣음. 앱은 서버 응답을 화면에 옮길 뿐
/// - 거래 마무리는 서버가 처리 끝냄(GRANTED · ALREADY_GRANTED) 뒤에만. PENDING·실패면 남겨 둠 > 스토어가 다음 실행에 다시 보냄
/// - 결제된 뒤의 실패는 `다시 확인하기` 로만 이어짐 (다시 결제 요구 금지)
class CreditPurchaseCoordinator {
  CreditPurchaseCoordinator(this._ref);

  final Ref _ref;

  /// 지금 서버 확인 중인 증빙 (같은 거래를 겹쳐 보내도 요청 1번)
  final Set<String> _verifyingKeys = {};

  /// 결제는 됐는데 서버가 아직 처리 끝내지 않은 마지막 구매 (`다시 확인하기` 대상)
  StorePurchaseUpdate? _lastUnsettledPurchase;

  /// StoreKit 2: 같은 상품에 끝나지 않은 거래가 있어 새 결제를 막음
  static const _duplicateTransactionCode = 'storekit_duplicate_product_object';

  StoreBillingClient get _store => _ref.read(storeBillingClientProvider);
  CreditPurchaseNotifier get _flow => _ref.read(creditPurchaseStateProvider.notifier);

  /// 결제: 구매 소식 듣기 > 회원 id 확인 > 결제창 (결과는 구매 소식으로). 보호자 암호 확인은 부르는 쪽이 끝냄
  Future<void> buy(CreditPack pack) async {
    if (!_flow.begin()) return;
    await _ref.read(storePurchaseCoordinatorProvider).start();
    final memberId = await _readMemberId();
    if (!isPurchaseAccountToken(memberId)) {
      AppLogger.info('[credit purchase] rejected : member id is not a uuid');
      _flow.failed(null, CreditPurchaseErrorCode.account);
      return;
    }
    try {
      final isLaunched = await _store.buyConsumable(productId: pack.productId, accountToken: memberId!);
      if (!isLaunched) _flow.failed(null, CreditPurchaseErrorCode.store);
    } on PlatformException catch (error, stack) {
      if (error.code == _duplicateTransactionCode) {
        // 이전 결제가 확인을 기다림 > 다시 결제시키지 않고 그 거래를 다시 확인
        AppLogger.info('[credit purchase] unfinished transaction exists : recheck');
        await retryVerification();
        return;
      }
      AppLogger.error('[credit purchase] buy failed', error, stack, {'code': error.code});
      _flow.failed(error, CreditPurchaseErrorCode.store);
    } catch (error, stack) {
      AppLogger.error('[credit purchase] buy failed', error, stack);
      _flow.failed(error, CreditPurchaseErrorCode.store);
    }
  }

  /// 구독 코디네이터가 넘긴 크레딧 상품 구매 소식 한 건
  Future<void> onStoreUpdate(StorePurchaseUpdate update) async {
    switch (update.status) {
      case StorePurchaseStatus.pending:
        _flow.needsRecheck();
      case StorePurchaseStatus.canceled:
        _flow.canceled();
      case StorePurchaseStatus.error:
        if (_ref.read(creditPurchaseStateProvider).isBusy) _flow.failed(update.errorCode, CreditPurchaseErrorCode.store);
      case StorePurchaseStatus.purchased:
      case StorePurchaseStatus.restored:
        await verify(update);
    }
  }

  /// `다시 확인하기`: 남은 구매를 다시 보냄. 기억한 구매가 없으면 스토어에 남은 거래를 다시 받아 확인
  Future<void> retryVerification() async {
    final unsettled = _lastUnsettledPurchase;
    if (unsettled != null) {
      await verify(unsettled);
      return;
    }
    _flow.startVerifying();
    try {
      await _store.restore();
      for (final purchase in await _store.unsettledPastPurchases()) {
        if (!isCreditProduct(purchase.productId)) continue;
        if (purchase.status == StorePurchaseStatus.purchased) await verify(purchase);
      }
    } catch (error, stack) {
      AppLogger.error('[credit purchase] recheck failed', error, stack);
    }
    // 되찾은 구매가 없으면 이미 넣었거나 확인할 것이 없음 > 잔액만 다시 받고 고르는 상태로
    if (_lastUnsettledPurchase == null && _ref.read(creditPurchaseStateProvider).isBusy) {
      refreshCreditSummary(_ref);
      _flow.settledSilently();
    }
  }

  /// 서버 확인 한 건 (순서: 증빙 > 서버 > 마무리 > 잔액 다시 받기)
  Future<void> verify(StorePurchaseUpdate update) async {
    if (!update.hasVerificationToken) return;
    if (!_verifyingKeys.add(update.dedupeKey)) return;
    try {
      if (!_canCallServer) {
        // 로그인 전·이룸이 기기 > 거래를 남겨 두면 다음 실행에 스토어가 다시 보냄
        _lastUnsettledPurchase = update;
        _flow.needsRecheck();
        return;
      }
      _flow.startVerifying();
      final attempt = await _request(update);
      final result = attempt.value;
      if (result == null) {
        _onVerifyFailed(update, attempt.failure);
        return;
      }
      if (!result.status.isSettled) {
        _lastUnsettledPurchase = update;
        _flow.needsRecheck(failureCode: CreditPurchaseErrorCode.verify);
        return;
      }
      await _finish(update);
      if (_lastUnsettledPurchase?.dedupeKey == update.dedupeKey) _lastUnsettledPurchase = null;
      refreshCreditSummary(_ref);
      // 같은 결제가 두 번 와서 이미 넣은 거래면 알림 띠 없이 조용히
      if (result.status == CreditPurchaseStatus.granted) {
        _flow.granted(result.grantedCredits);
      } else {
        _flow.settledSilently();
      }
    } finally {
      _verifyingKeys.remove(update.dedupeKey);
    }
  }

  /// 앱 시작 때 끝나지 않은 크레딧 구매를 조용히 다시 확인 (구독 코디네이터의 Android 재확인이 넘김)
  Future<void> recheckSilently(StorePurchaseUpdate update) async {
    if (update.status == StorePurchaseStatus.purchased) await verify(update);
  }

  /// 이 상품 id 가 크레딧 꾸러미인가 (구독 상품이 아니면 소모성으로 봄)
  static bool isCreditProduct(String productId) => !isSubscriptionProduct(productId);

  Future<Attempt<CreditPurchaseResult>> _request(StorePurchaseUpdate update) {
    final repository = _ref.read(creditPackServiceProvider);
    return switch (update.platform) {
      StorePlatform.appStore => repository.verifyApple(update.verificationToken),
      StorePlatform.googlePlay => repository.verifyGoogle(
        productId: update.productId,
        purchaseToken: update.verificationToken,
      ),
    };
  }

  /// 확인 실패: 거래는 남겨 둠. 400 은 다시 해도 같아 실패로 끝냄, 그 밖(연결 · 5xx)은 `다시 확인하기`
  void _onVerifyFailed(StorePurchaseUpdate update, AppFailure? failure) {
    final isRetryable = failure == null || failure.server?.statusCode != 400;
    AppLogger.info('[credit purchase] verification failed : ${failure?.badgeOr(CreditPurchaseErrorCode.verify)} retryable=$isRetryable');
    if (isRetryable) {
      _lastUnsettledPurchase = update;
      _flow.needsRecheck(failure: failure, failureCode: CreditPurchaseErrorCode.verify);
    } else {
      _flow.failed(failure, CreditPurchaseErrorCode.verify);
    }
  }

  /// 거래 마무리: Apple 은 처리 끝났으면 finish, Google 은 아직 acknowledge 안 됐을 때만 (소비는 서버가 함)
  Future<void> _finish(StorePurchaseUpdate update) async {
    final shouldFinish = update.platform == StorePlatform.appStore || !update.isAcknowledged;
    if (!shouldFinish) return;
    try {
      await _store.finish(update);
    } catch (error, stack) {
      // 마무리 실패는 서버 반영과 무관 > 다음 실행에 스토어가 다시 보내면 같은 결과로 다시 마무리
      AppLogger.error('[credit purchase] finish failed', error, stack);
    }
  }

  /// 서버에 보낼 수 있는가: 보호자 기기 + 로그인됨
  bool get _canCallServer =>
      !_ref.read(localStorageProvider).isElumiDevice && _ref.read(authSessionControllerProvider).hasSession;

  Future<String?> _readMemberId() async {
    final cached = _ref.read(memberProvider).value?.id;
    if (cached != null) return cached;
    try {
      return (await _ref.read(memberProvider.future))?.id;
    } catch (_) {
      return null;
    }
  }
}

final creditPurchaseCoordinatorProvider = Provider<CreditPurchaseCoordinator>(
  (ref) => CreditPurchaseCoordinator(ref),
);
