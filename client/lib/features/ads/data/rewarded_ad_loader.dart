import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logger/app_logger.dart';
import 'ad_consent.dart';
import '../../../core/config/ad_ids.dart';
import 'ad_sdk.dart';

/// 보상형 광고 한 번이 어떻게 끝났나.
enum RewardedAdEnd {
  /// 끝까지 봐서 SDK 가 보상을 인정했다. **지급은 아니다** — 지급은 서버 SSV 가 정한다.
  earned,

  /// 보다가 닫았다. 보상 없음.
  dismissed,

  /// 광고 없음(no fill)·오프라인·SDK 오류·시간 초과·표시 실패.
  loadFailed,
}

/// 보상형 광고를 불러와 보여 준다. 테스트는 이것을 가짜로 바꿔 SDK 를 띄우지 않는다.
abstract interface class RewardedAdLoader {
  /// 광고 단위가 있는가. 릴리스인데 `.env` 가 비어 있으면 false — 버튼 자체를 숨긴다.
  bool get isConfigured;

  /// 광고 미리 불러 두기 > 준비됐으면 true (이미 불러 둔 것 · 불러오는 중이면 그것을 기다림)
  /// **예외를 던지지 않는다** — 실패 · 단위 없음은 false
  Future<bool> preload();

  /// [nonce] 를 SSV customData 로 실어 광고를 보여 주고 끝날 때까지 기다린다.
  /// **예외를 던지지 않는다** — 실패는 [RewardedAdEnd.loadFailed] 다.
  Future<RewardedAdEnd> showFor(String nonce);
}

final rewardedAdLoaderProvider = Provider<RewardedAdLoader>(
  (ref) => GoogleRewardedAdLoader(),
);

/// google_mobile_ads 구현: 미리 불러 둔 광고 1개 > 보여 주기 직전에 세션 nonce 를 SSV customData 로 붙임
///
/// 미리 불러 두는 광고는 1개뿐 (쌓이지 않음). SSV customData 는 불러온 뒤에도 보여 주기 전이면 붙일 수 있음
class GoogleRewardedAdLoader implements RewardedAdLoader {
  /// 광고가 이만큼 안 오면 포기한다 — 눌렀는데 빈 대기 화면이 길게 남지 않게 한다.
  static const _loadTimeout = Duration(seconds: 20);

  /// 미리 불러 둔 광고를 쓰는 상한 (AdMob 광고는 불러온 지 1시간이면 만료 > 여유 두고 50분)
  static const _preloadedAdMaxAge = Duration(minutes: 50);

  RewardedAd? _preloadedAd;
  DateTime? _preloadedAt;

  /// 불러오는 중인 요청 (같은 때 두 번 불러오지 않게)
  Future<void>? _loadingAd;

  String? get _unitId =>
      AppConfig.adUnitId(AdPlacement.rewardedCredit, isIos: Platform.isIOS);

  @override
  bool get isConfigured => _unitId != null;

  @override
  Future<bool> preload() async {
    if (_takeFreshPreloadedAd(keep: true) != null) return true;
    await _loadOnce();
    return _takeFreshPreloadedAd(keep: true) != null;
  }

  /// 미리 불러 둔 광고 (만료 전만). [keep] 이 false 면 꺼내 가며 비움 (한 번 보인 광고는 다시 못 씀)
  RewardedAd? _takeFreshPreloadedAd({required bool keep}) {
    final ad = _preloadedAd;
    final loadedAt = _preloadedAt;
    if (ad == null || loadedAt == null) return null;
    if (DateTime.now().difference(loadedAt) > _preloadedAdMaxAge) {
      ad.dispose();
      _preloadedAd = null;
      _preloadedAt = null;
      return null;
    }
    if (!keep) {
      _preloadedAd = null;
      _preloadedAt = null;
    }
    return ad;
  }

  /// 불러오기 1회 > 미리 불러 둔 칸에 넣음 (이미 불러오는 중이면 그 요청을 기다림, 넣는 곳은 여기 하나)
  Future<void> _loadOnce() {
    return _loadingAd ??= _load().then((ad) {
      _loadingAd = null;
      if (ad == null) return;
      _preloadedAd?.dispose();
      _preloadedAd = ad;
      _preloadedAt = DateTime.now();
    });
  }

  /// 광고 불러오기 > 광고 (없음 · 실패 · 시간 초과면 null, 던지지 않음)
  Future<RewardedAd?> _load() async {
    try {
      final unitId = _unitId;
      if (unitId == null) return null;

      await AdSdk.ensureInitialized();
      final nonPersonalized = await AdConsent.useNonPersonalized();

      final loaded = Completer<RewardedAd?>();
      await RewardedAd.load(
        adUnitId: unitId,
        // 요청에 넘기는 것은 비개인화 여부뿐이다. 이룸이·보호자 정보는 넘기지 않는다.
        request: AdRequest(nonPersonalizedAds: nonPersonalized),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            // 시간 초과 뒤에 늦게 온 광고는 쓰지 않고 해제한다.
            if (loaded.isCompleted) {
              ad.dispose();
            } else {
              loaded.complete(ad);
            }
          },
          onAdFailedToLoad: (error) {
            AppLogger.error('보상형 로드 실패', error);
            if (!loaded.isCompleted) loaded.complete(null);
          },
        ),
      );
      return await loaded.future.timeout(
        _loadTimeout,
        onTimeout: () {
          AppLogger.error('보상형 로드 시간 초과', null);
          return null;
        },
      );
    } catch (e, st) {
      AppLogger.error('보상형 불러오기 실패', e, st);
      return null;
    }
  }

  @override
  Future<RewardedAdEnd> showFor(String nonce) async {
    try {
      // 미리 불러 둔 광고 > 없으면 지금 불러옴 (불러오는 중이면 그것을 기다림)
      if (!await preload()) return RewardedAdEnd.loadFailed;
      final ad = _takeFreshPreloadedAd(keep: false);
      if (ad == null) return RewardedAdEnd.loadFailed;

      // 서버가 이 값으로 어느 회원의 시청인지 찾는다(SSV customData).
      await ad.setServerSideOptions(
        ServerSideVerificationOptions(customData: nonce),
      );

      final done = Completer<RewardedAdEnd>();
      var earned = false;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (a) {
          a.dispose();
          if (!done.isCompleted) {
            done.complete(
              earned ? RewardedAdEnd.earned : RewardedAdEnd.dismissed,
            );
          }
        },
        onAdFailedToShowFullScreenContent: (a, error) {
          AppLogger.error('보상형 표시 실패', error);
          a.dispose();
          if (!done.isCompleted) done.complete(RewardedAdEnd.loadFailed);
        },
      );
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
      return await done.future;
    } catch (e, st) {
      // 광고는 보조 흐름이다. 삼키지 않고 남기되 호출한 쪽에는 실패로 돌려준다.
      AppLogger.error('보상형 준비 실패', e, st);
      return RewardedAdEnd.loadFailed;
    }
  }
}
