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

  /// [nonce] 를 SSV customData 로 실어 광고를 보여 주고 끝날 때까지 기다린다.
  /// **예외를 던지지 않는다** — 실패는 [RewardedAdEnd.loadFailed] 다.
  Future<RewardedAdEnd> showFor(String nonce);
}

final rewardedAdLoaderProvider = Provider<RewardedAdLoader>(
  (ref) => GoogleRewardedAdLoader(),
);

/// google_mobile_ads 구현.
///
/// 광고는 **세션을 만든 뒤에** 불러온다. 미리 불러 두면 쓰지 않은 광고가 쌓이고 SSV
/// customData 도 붙일 수 없다(nonce 는 세션마다 새로 나온다).
class GoogleRewardedAdLoader implements RewardedAdLoader {
  /// 광고가 이만큼 안 오면 포기한다 — 눌렀는데 빈 대기 화면이 길게 남지 않게 한다.
  static const _loadTimeout = Duration(seconds: 20);

  String? get _unitId =>
      AppConfig.adUnitId(AdPlacement.rewardedCredit, isIos: Platform.isIOS);

  @override
  bool get isConfigured => _unitId != null;

  @override
  Future<RewardedAdEnd> showFor(String nonce) async {
    try {
      final unitId = _unitId;
      if (unitId == null) return RewardedAdEnd.loadFailed;

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
      final ad = await loaded.future.timeout(
        _loadTimeout,
        onTimeout: () {
          AppLogger.error('보상형 로드 시간 초과', null);
          return null;
        },
      );
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
