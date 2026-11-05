import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/storage/local_storage.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../credit/application/credit_summary_refresh.dart';
import '../../member/application/member_providers.dart';
import '../data/store_billing_client.dart';
import '../data/subscription_verify_repository.dart';
import '../domain/plan_catalog.dart';
import '../domain/plan_error_code.dart';
import '../domain/plan_purchase_state.dart';
import '../domain/store_purchase_update.dart';
import '../domain/store_verification.dart';
import 'plan_purchase_notifier.dart';
import 'plan_store_catalog.dart';

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
class StorePurchaseCoordinator {
  StorePurchaseCoordinator(this._ref);

  final Ref _ref;

  StreamSubscription<List<StorePurchaseUpdate>>? _purchaseSubscription;

  /// 지금 서버 확인 중인 증빙
  final Set<String> _verifyingKeys = {};

  /// 결제는 됐는데 아직 서버가 처리 끝내지 않은 마지막 구매 (요금제 화면 `다시 확인` 대상)
  StorePurchaseUpdate? _lastUnsettledPurchase;

  /// 복원 중이면 그동안 확인 실패 원인을 모음
  bool _isRestoring = false;
  Object? _restoreFailure;

  /// 복원 요청 뒤 스토어가 복원 소식을 다 보낼 때까지 기다리는 시간
  static const _restoreSettleDelay = Duration(seconds: 2);

  /// 복원 소식 서버 확인을 기다리는 최대 시간
  static const _restoreMaxWait = Duration(seconds: 20);
  static const _restorePollInterval = Duration(milliseconds: 200);

  /// StoreKit 2: 같은 상품에 끝나지 않은 거래가 있어 새 결제를 막음 (in_app_purchase_storekit)
  static const _duplicateTransactionCode = 'storekit_duplicate_product_object';

  StoreBillingClient get _store => _ref.read(storeBillingClientProvider);
  PlanPurchaseNotifier get _flow => _ref.read(planPurchaseStateProvider.notifier);

  /// 구매 소식 듣기 시작 + Android 미확인 구매 다시 확인 (앱 시작 · 요금제 화면 열 때, 여러 번 불러도 1번)
  ///
  /// 보호자 기기 + 스토어 연동일 때만 (서버 판매 스위치와 무관 — 기존 구독 갱신·미확인 결제 처리 유지). 이룸이 기기는 스토어를 건드리지 않음
  Future<void> start() async {
    if (_purchaseSubscription != null) return;
    if (!_ref.read(isPlanStoreConnectedProvider)) return;
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
    final unsettled = _lastUnsettledPurchase;
    if (unsettled != null) {
      await _verify(unsettled);
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
            isRetryable: _isRetryable(outcome.failure),
          ),
        );
    }
  }

  /// 구매 복원: 스토어 복원 > 복원 소식 서버 확인 대기 > 회원 정보 다시 받아 Pro 인지 확인
  Future<PlanRestoreOutcome> restore() async {
    await start();
    _isRestoring = true;
    _restoreFailure = null;
    try {
      await _store.restore();
      await Future<void>.delayed(_restoreSettleDelay);
      await _waitForVerifications();
      final failure = _restoreFailure;
      final member = await _ref.refresh(memberProvider.future);
      if (member?.isPro == true) {
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
      _isRestoring = false;
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
          await _verify(update);
      }
    }
  }

  /// 서버 확인 한 건: 증빙 확인 > 서버 요청 > (처리 끝났으면) 거래 마무리 > 회원·크레딧 다시 받기
  Future<void> _verify(StorePurchaseUpdate update) async {
    if (!update.hasVerificationToken) {
      AppLogger.info('[plan purchase] skipped : empty verification token');
      return;
    }
    if (!_verifyingKeys.add(update.dedupeKey)) return;
    try {
      if (!_canCallServer) {
        // 로그인 전·이룸이 기기 > 거래를 남겨 두면 다음 실행에 스토어가 다시 보냄
        _rememberUnsettled(update);
        _flow.apply(const PlanPurchaseEvent.verificationFailed(null, isRetryable: true));
        return;
      }
      _flow.apply(const PlanPurchaseEvent.verificationStarted());
      final attempt = await _requestVerification(update);
      final verificationResult = attempt.value;
      if (verificationResult == null) {
        _onVerificationFailed(update, attempt.failure);
        return;
      }
      if (verificationResult.verification.isSettled) {
        await _settle(update, verificationResult.verification);
        _forgetUnsettled(update);
      } else {
        _rememberUnsettled(update);
      }
      _refreshPlanViews();
      _flow.apply(PlanPurchaseEvent.verificationFinished(verificationResult.verification));
    } finally {
      _verifyingKeys.remove(update.dedupeKey);
    }
  }

  Future<Attempt<StoreVerificationResult>> _requestVerification(
    StorePurchaseUpdate update,
  ) {
    final repository = _ref.read(subscriptionVerifyRepositoryProvider);
    return switch (update.platform) {
      StorePlatform.appStore => repository.verifyApple(update.verificationToken),
      StorePlatform.googlePlay => repository.verifyGoogle(
        purchaseToken: update.verificationToken,
        productId: update.productId,
      ),
    };
  }

  /// 확인 실패: 거래는 남겨 둠 (다음 실행·다시 확인에서 재시도). 400 은 다시 해도 같아 실패로 끝냄
  void _onVerificationFailed(StorePurchaseUpdate update, AppFailure? failure) {
    final isRetryable = _isRetryable(failure);
    AppLogger.info(
      '[plan purchase] verification failed : ${failure?.badgeOr(PlanErrorCode.verify)} retryable=$isRetryable',
    );
    if (isRetryable) _rememberUnsettled(update);
    if (_isRestoring) _restoreFailure = failure;
    _flow.apply(PlanPurchaseEvent.verificationFailed(failure, isRetryable: isRetryable));
  }

  /// 거래 마무리: Apple 은 처리 끝났으면 finish, Google 은 ACTIVE 인데 아직 acknowledge 안 됐을 때만
  Future<void> _settle(StorePurchaseUpdate update, StoreVerification verification) async {
    final shouldFinish = switch (update.platform) {
      StorePlatform.appStore => true,
      StorePlatform.googlePlay =>
        verification == StoreVerification.active && !update.isAcknowledged,
    };
    if (!shouldFinish) return;
    try {
      await _store.finish(update);
    } catch (error, stack) {
      // 마무리 실패는 서버 반영과 무관 > 다음 실행에 스토어가 다시 보내면 같은 결과로 다시 마무리
      AppLogger.error('[plan purchase] finish failed', error, stack);
    }
  }

  /// 서버가 바꾼 요금제·크레딧을 화면이 다시 받게
  void _refreshPlanViews() {
    _ref.invalidate(memberProvider);
    refreshCreditSummary(_ref);
  }

  /// Android: acknowledge 안 된 지난 구매를 조용히 다시 확인 (서버 확인이 끊긴 결제)
  Future<void> _recheckUnsettledPurchases() async {
    if (!_canCallServer) return;
    try {
      final purchases = await _store.unsettledPastPurchases();
      for (final purchase in purchases) {
        if (purchase.status == StorePurchaseStatus.purchased) await _verify(purchase);
      }
    } catch (error, stack) {
      AppLogger.error('[plan purchase] past purchases failed', error, stack);
    }
  }

  Future<void> _waitForVerifications() async {
    final deadline = DateTime.now().add(_restoreMaxWait);
    while (_verifyingKeys.isNotEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_restorePollInterval);
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

  /// 서버에 결제 확인을 보낼 수 있는가: 보호자 기기 + 로그인됨 (로그인 전 요청은 세션 만료 처리로 번짐)
  bool get _canCallServer =>
      !_ref.read(localStorageProvider).isElumiDevice &&
      _ref.read(authSessionControllerProvider).hasSession;

  void _rememberUnsettled(StorePurchaseUpdate update) => _lastUnsettledPurchase = update;

  void _forgetUnsettled(StorePurchaseUpdate update) {
    if (_lastUnsettledPurchase?.dedupeKey == update.dedupeKey) {
      _lastUnsettledPurchase = null;
    }
  }

  /// 다시 해 볼 만한 실패인가: 서버가 400 으로 거부한 것(위조·다른 계정·허용 밖 상품·테스트 결제)만 아님
  static bool _isRetryable(Object? failure) {
    if (failure is! AppFailure) return true;
    return failure.server?.statusCode != 400;
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
