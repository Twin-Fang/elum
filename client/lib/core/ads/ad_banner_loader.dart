import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';
import '../logger/app_logger.dart';
import 'ad_consent.dart';
import 'ad_ids.dart';

/// 로드가 끝난 배너. 슬롯이 그리고 화면을 떠날 때 [dispose]로 해제한다.
class LoadedBanner {
  LoadedBanner({
    required this.height,
    required this.widget,
    required this.dispose,
  });

  final double height;
  final Widget widget;
  final VoidCallback dispose;
}

/// 배너를 불러온다. 테스트는 이것을 가짜로 바꿔 SDK를 띄우지 않는다.
abstract interface class AdBannerLoader {
  /// 실패·미지원이면 null. **예외를 던지지 않는다.**
  Future<LoadedBanner?> load(AdPlacement placement, int widthDp);
}

final adBannerLoaderProvider = Provider<AdBannerLoader>(
  (ref) => GoogleAdBannerLoader(),
);

/// google_mobile_ads 구현.
///
/// SDK는 **처음 배너를 요청할 때** 초기화한다. 이룸이 전용 휴대폰은 보호자 화면을
/// 열지 않으므로 SDK가 시작되지도 않는다.
class GoogleAdBannerLoader implements AdBannerLoader {
  static Future<void>? _init;

  static Future<void> _ensureInitialized() => _init ??= () async {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            // 성인·선정 광고를 줄인다. 보호자 화면이라도 이룸이가 볼 수 있다.
            maxAdContentRating: MaxAdContentRating.pg,
          ),
        );
        await MobileAds.instance.initialize();
      }();

  @override
  Future<LoadedBanner?> load(AdPlacement placement, int widthDp) async {
    // 폭 0에서 적응형 배너를 요청하면 예외가 난다(첫 프레임).
    if (widthDp <= 0) return null;
    try {
      final unitId = AppConfig.adUnitId(placement, isIos: Platform.isIOS);
      // 릴리스인데 .env가 비었다 — 광고를 띄우지 않는다.
      if (unitId == null) return null;

      await _ensureInitialized();
      final nonPersonalized = await AdConsent.useNonPersonalized();
      final size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            widthDp,
          );
      if (size == null) return null;

      final done = Completer<BannerAd?>();
      final ad = BannerAd(
        adUnitId: unitId,
        size: size,
        // 요청에 넘기는 것은 비개인화 여부뿐이다. 이룸이·보호자 정보는 넘기지 않는다.
        request: AdRequest(nonPersonalizedAds: nonPersonalized),
        listener: BannerAdListener(
          onAdLoaded: (a) => done.complete(a as BannerAd),
          onAdFailedToLoad: (a, error) {
            AppLogger.error('배너 로드 실패 ${placement.name}', error);
            a.dispose();
            done.complete(null);
          },
        ),
      );
      await ad.load();
      final loaded = await done.future;
      if (loaded == null) return null;
      return LoadedBanner(
        height: size.height.toDouble(),
        widget: SizedBox(
          width: size.width.toDouble(),
          height: size.height.toDouble(),
          child: AdWidget(ad: loaded),
        ),
        dispose: loaded.dispose,
      );
    } catch (e, st) {
      // 광고는 보조 요소라 사용자에게 알리지 않는다. 다만 삼키지 않고 남긴다.
      AppLogger.error('배너 준비 실패 ${placement.name}', e, st);
      return null;
    }
  }
}
