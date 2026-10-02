import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ads/ad_gate.dart';
import '../../../core/ads/rewarded_ad_loader.dart';
import '../../../core/l10n/current_l10n.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/server_error_code.dart';
import '../data/ad_reward_repository.dart';
import '../domain/ad_reward.dart';

/// 제안을 기다리는 상한. 크레딧 소진 안내가 이 때문에 늦게 뜨지 않는다 —
/// 넘기면 버튼 없이 원래 안내만 보인다.
const adRewardOfferTimeout = Duration(seconds: 3);

/// 흐름이 어디까지 왔나 — 화면이 대기 문구를 바꾼다.
enum AdRewardStage {
  /// 세션을 만들고 광고를 불러오는 중. 광고가 뜨면 이 화면은 광고 뒤로 가려진다.
  preparing,

  /// 광고를 끝까지 봤다. 서버가 지급했는지 묻는 중.
  confirming,
}

/// 사용자에게 보일 실패 한 건. [code] 는 제보를 받았을 때 추적할 식별자다.
class AdRewardFailure {
  const AdRewardFailure({required this.sentence, required this.code});

  /// 시안 팝업 문장 모양 — `무엇이 안 됐는지.\n무엇을 하면 되는지`.
  final String sentence;
  final String code;
}

/// 흐름의 끝. 지급됐거나([granted]) 안내할 실패가 있다([failure]) 둘 중 하나다.
class AdRewardResult {
  const AdRewardResult.granted(this.grantedCredits) : failure = null;
  const AdRewardResult.failed(AdRewardFailure this.failure)
    : grantedCredits = 0;

  final int grantedCredits;
  final AdRewardFailure? failure;

  bool get granted => failure == null;
}

/// 크레딧 소진 안내의 "광고 보고 더 만들기" 흐름 (#464, 설계 §7).
///
/// 1. [offer] — 서버가 켜 두었고 오늘 횟수가 남았을 때만 버튼을 보인다.
/// 2. [run] — 세션 만들기 → 광고(nonce 를 customData 로) → **서버가 지급했는지 상태 조회**.
///
/// **앱은 지급을 선언하지 않는다.** "봤다"고 알리는 API 가 없고, 서버가 SSV 콜백으로
/// 확인해 지급한 것만 [AdRewardResult.granted] 가 된다. 시청이 끝나도 서버 확인이 안 오면
/// 지급으로 치지 않는다.
///
/// 어떤 실패도 던지지 않고 [AdRewardFailure] 로 돌려준다 — 화면은 코드를 보이고 원래
/// 화면으로 돌아온다.
class AdRewardFlow {
  AdRewardFlow({
    required this.repository,
    required this.loader,
    required this.adsEnabled,
    this.pollInterval = const Duration(seconds: 2),
    // 2초 × 10 = 20초. SSV 콜백은 보통 몇 초 안에 온다.
    this.maxPolls = 10,
  });

  final AdRewardRepository repository;
  final RewardedAdLoader loader;
  final bool adsEnabled;
  final Duration pollInterval;
  final int maxPolls;

  /// 버튼을 보일 때만 제안을, 아니면 null.
  ///
  /// 모르면 숨긴다 — 광고를 못 띄우는 환경, 릴리스인데 `.env` 광고 단위가 빈 빌드,
  /// 서버가 꺼 둔 설정, 조회 실패 모두 같다. 그래서 운영이 꺼져 있는 지금은 화면이 그대로다.
  Future<AdRewardOffer?> offer() async {
    if (!adsEnabled || !loader.isConfigured) return null;
    try {
      final offer = await repository.getOffer().timeout(adRewardOfferTimeout);
      return offer.canOffer ? offer : null;
    } catch (e) {
      // 숨기는 것은 의도지만 실패가 묻히면 원인을 못 찾는다.
      AppLogger.error('AdRewardFlow.offer (조회 실패 — 버튼을 숨긴다)', e);
      return null;
    }
  }

  Future<AdRewardResult> run({
    void Function(AdRewardStage stage)? onStage,
  }) async {
    onStage?.call(AdRewardStage.preparing);

    final AdRewardSession session;
    try {
      session = await repository.createSession();
    } catch (e) {
      return AdRewardResult.failed(_sessionFailure(AppFailure.of(e)));
    }

    RewardedAdEnd end;
    try {
      end = await loader.showFor(session.nonce);
    } catch (e, st) {
      // 로더는 던지지 않는 계약이지만 SDK 쪽이 계약을 어겨도 화면은 살아 있어야 한다.
      AppLogger.error('AdRewardFlow 광고 표시 예외', e, st);
      end = RewardedAdEnd.loadFailed;
    }
    switch (end) {
      case RewardedAdEnd.loadFailed:
        return AdRewardResult.failed(
          AdRewardFailure(
            sentence: appL10n.adRewardLoadFailed,
            code: 'E-AD-LOAD',
          ),
        );
      case RewardedAdEnd.dismissed:
        return AdRewardResult.failed(
          AdRewardFailure(
            sentence: appL10n.adRewardNotWatched,
            code: 'E-AD-SKIP',
          ),
        );
      case RewardedAdEnd.earned:
        onStage?.call(AdRewardStage.confirming);
        return _waitForGrant(session.nonce);
    }
  }

  /// 서버가 지급했는지 정해진 횟수만큼 묻는다. 일시적 오류는 건너뛰고 계속 묻는다 —
  /// 광고는 이미 봤고 지급은 서버가 따로 하므로, 한 번의 네트워크 끊김으로 포기하지 않는다.
  Future<AdRewardResult> _waitForGrant(String nonce) async {
    for (var i = 0; i < maxPolls; i++) {
      if (i > 0) await Future<void>.delayed(pollInterval);
      try {
        final status = await repository.getStatus(nonce);
        switch (status.phase) {
          case AdRewardPhase.pending:
            continue;
          case AdRewardPhase.granted:
            return AdRewardResult.granted(status.grantedCredits);
          case AdRewardPhase.rejected:
            return AdRewardResult.failed(_rejectedFailure(status.reason));
          case AdRewardPhase.expired:
            return AdRewardResult.failed(_rejectedFailure('EXPIRED'));
        }
      } catch (e) {
        final failure = AppFailure.of(e);
        // 세션이 없다는 답은 다시 물어도 같다.
        if (failure.server?.code == ServerErrorCode.adRewardSessionNotFound) {
          return AdRewardResult.failed(_sessionFailure(failure));
        }
        AppLogger.error('AdRewardFlow 상태 조회 실패 — 계속 기다린다', e);
      }
    }
    // 시청은 끝났는데 확인이 오지 않았다. 늦게 지급될 수 있으니 설정에서 확인하게 한다.
    return AdRewardResult.failed(
      AdRewardFailure(sentence: appL10n.adRewardSlow, code: 'E-AD-WAIT'),
    );
  }

  /// 세션을 못 만든 이유. 서버가 문구를 줬으면 그것이 이긴다(AppFailure 규칙).
  AdRewardFailure _sessionFailure(AppFailure failure) {
    final fallback = switch (failure.server?.code) {
      ServerErrorCode.adRewardDailyLimit => appL10n.adRewardDailyLimit,
      ServerErrorCode.adRewardAccountFrozen => appL10n.adRewardCheckAccount,
      ServerErrorCode.adRewardDisabled => appL10n.adRewardUnavailable,
      _ => appL10n.adRewardUnavailableRetry,
    };
    return AdRewardFailure(
      sentence: failure.serverMessage ?? failure.hint ?? fallback,
      code: failure.badgeOr('E-AD-SESSION'),
    );
  }

  /// 서버가 콜백은 받았지만 지급하지 않은 이유(`reason`)를 안내로 바꾼다.
  AdRewardFailure _rejectedFailure(String? reason) {
    final (sentence, code) = switch (reason) {
      'DAILY_LIMIT' => (
        appL10n.adRewardDailyLimit,
        ServerErrorCode.adRewardDailyLimit.wire,
      ),
      'FROZEN' => (
        appL10n.adRewardCheckAccount,
        ServerErrorCode.adRewardAccountFrozen.wire,
      ),
      'DISABLED' => (
        appL10n.adRewardUnavailable,
        ServerErrorCode.adRewardDisabled.wire,
      ),
      // EXPIRED · NOT_PENDING · AD_UNIT · 모르는 값 — 사용자가 할 일은 같다.
      _ => (appL10n.adRewardFailed, 'AD_REWARD_${reason ?? 'UNKNOWN'}'),
    };
    return AdRewardFailure(sentence: sentence, code: code);
  }
}

final adRewardFlowProvider = Provider<AdRewardFlow>(
  (ref) => AdRewardFlow(
    repository: ref.watch(adRewardRepositoryProvider),
    loader: ref.watch(rewardedAdLoaderProvider),
    adsEnabled: ref.watch(adsEnabledProvider),
  ),
);
