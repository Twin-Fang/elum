import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/storage/local_storage.dart';
import '../../auth/application/auth_session_controller.dart';
import '../../credit/application/credit_summary_refresh.dart';
import '../../member/application/member_providers.dart';
import '../data/store_billing_client.dart';
import '../data/subscription_verify_repository.dart';
import '../domain/plan_error_code.dart';
import '../domain/plan_purchase_state.dart';
import '../domain/store_purchase_update.dart';
import '../domain/store_verification.dart';
import 'plan_purchase_notifier.dart';

/// 구매 한 건 서버 확인: 증빙 확인 > 서버 요청 > (처리 끝났으면) 거래 마무리 > 회원·크레딧 다시 받기
///
/// 같은 증빙은 동시에 한 번만 확인. 처리 안 끝난 마지막 구매를 기억(`다시 확인` 대상), 복원 중이면 실패 원인을 모음.
/// `StorePurchaseCoordinator` 가 만들어 씀
class StorePurchaseVerifier {
  StorePurchaseVerifier(this._ref);

  final Ref _ref;

  /// 지금 서버 확인 중인 증빙
  final Set<String> _verifyingKeys = {};

  /// 결제는 됐는데 아직 서버가 처리 끝내지 않은 마지막 구매 (요금제 화면 `다시 확인` 대상)
  StorePurchaseUpdate? _lastUnsettledPurchase;

  /// 복원 중이면 그동안 확인 실패 원인을 모음
  bool _isRestoring = false;
  Object? _restoreFailure;

  /// 복원 소식 서버 확인을 기다리는 최대 시간
  static const _restoreMaxWait = Duration(seconds: 20);
  static const _restorePollInterval = Duration(milliseconds: 200);

  StoreBillingClient get _store => _ref.read(storeBillingClientProvider);
  PlanPurchaseNotifier get _flow => _ref.read(planPurchaseStateProvider.notifier);

  StorePurchaseUpdate? get lastUnsettledPurchase => _lastUnsettledPurchase;

  /// 복원 시작: 실패 원인 모으기 시작 (이전 원인은 비움)
  void beginRestore() {
    _isRestoring = true;
    _restoreFailure = null;
  }

  /// 복원 중 모은 마지막 확인 실패 원인 (없으면 null)
  Object? get restoreFailure => _restoreFailure;

  void endRestore() => _isRestoring = false;

  /// 서버 확인 한 건 (순서: 증빙 > 서버 > 마무리 > 다시 받기)
  Future<void> verify(StorePurchaseUpdate update) async {
    if (!update.hasVerificationToken) {
      AppLogger.info('[plan purchase] skipped : empty verification token');
      return;
    }
    if (!_verifyingKeys.add(update.dedupeKey)) return;
    try {
      if (!canCallServer) {
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

  /// 진행 중인 확인이 끝날 때까지 기다림 (최대 [_restoreMaxWait])
  Future<void> waitForVerifications() async {
    final deadline = DateTime.now().add(_restoreMaxWait);
    while (_verifyingKeys.isNotEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_restorePollInterval);
    }
  }

  /// 서버에 결제 확인을 보낼 수 있는가: 보호자 기기 + 로그인됨 (로그인 전 요청은 세션 만료 처리로 번짐)
  bool get canCallServer =>
      !_ref.read(localStorageProvider).isElumiDevice &&
      _ref.read(authSessionControllerProvider).hasSession;

  /// 다시 해 볼 만한 실패인가: 서버가 400 으로 거부한 것(위조·다른 계정·허용 밖 상품·테스트 결제)만 아님
  static bool isRetryable(Object? failure) {
    if (failure is! AppFailure) return true;
    return failure.server?.statusCode != 400;
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
    final isRetryable = StorePurchaseVerifier.isRetryable(failure);
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

  void _rememberUnsettled(StorePurchaseUpdate update) => _lastUnsettledPurchase = update;

  void _forgetUnsettled(StorePurchaseUpdate update) {
    if (_lastUnsettledPurchase?.dedupeKey == update.dedupeKey) {
      _lastUnsettledPurchase = null;
    }
  }
}
