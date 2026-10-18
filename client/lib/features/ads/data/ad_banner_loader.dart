import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/app_config.dart';
import '../../../core/logger/app_logger.dart';
import 'ad_consent.dart';
import '../../../core/config/ad_ids.dart';
import 'ad_sdk.dart';

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
  Future<LoadedBanner?> load(AdPlacement placement);
}

final adBannerLoaderProvider = Provider<AdBannerLoader>(
  (ref) => GoogleAdBannerLoader(),
);

/// google_mobile_ads 구현.
///
/// 크기는 표준 배너(320x50) 하나로 고정한다. 적응형 앵커 배너는 기기 폭에 따라 높이가 커지고
/// 상품 썸네일 캐러셀 같은 큰 소재가 올라와 화면이 번잡해진다.
///
/// SDK는 **처음 배너를 요청할 때** 초기화한다. 이룸이 전용 휴대폰은 보호자 화면을
/// 열지 않으므로 SDK가 시작되지도 않는다.
class GoogleAdBannerLoader implements AdBannerLoader {
  @override
  Future<LoadedBanner?> load(AdPlacement placement) async {
    try {
      final unitId = AppConfig.adUnitId(placement, isIos: Platform.isIOS);
      // 릴리스인데 .env가 비었다 — 광고를 띄우지 않는다.
      if (unitId == null) return null;

      await AdSdk.ensureInitialized();
      final nonPersonalized = await AdConsent.useNonPersonalized();
      const size = AdSize.banner;

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
