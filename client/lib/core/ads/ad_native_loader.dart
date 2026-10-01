import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/app_config.dart';
import '../logger/app_logger.dart';
import 'ad_consent.dart';
import 'ad_ids.dart';
import 'ad_sdk.dart';

/// 로드가 끝난 네이티브 광고. 슬롯이 그리고 화면을 떠날 때 [dispose]로 해제한다.
class LoadedNative {
  LoadedNative({
    required this.height,
    required this.widget,
    required this.dispose,
  });

  final double height;
  final Widget widget;
  final VoidCallback dispose;
}

/// 네이티브 광고를 불러온다. 테스트는 이것을 가짜로 바꿔 SDK를 띄우지 않는다.
abstract interface class AdNativeLoader {
  /// 실패·미지원이면 null. **예외를 던지지 않는다.**
  Future<LoadedNative?> load(AdPlacement placement, int widthDp);
}

final adNativeLoaderProvider = Provider<AdNativeLoader>(
  (ref) => GoogleAdNativeLoader(),
);

/// google_mobile_ads 구현.
///
/// 광고주 이미지·문구는 SDK 템플릿(`small`)이 그린다. 앱 쪽 네이티브 팩토리를 따로
/// 등록하지 않아도 되고, 광고 에셋을 앱이 임의로 가공하지 않는다(정책).
class GoogleAdNativeLoader implements AdNativeLoader {
  /// 템플릿 `small` 이 그려지는 높이. 이보다 작으면 잘린다.
  static const _height = 100.0;

  /// 광고가 이만큼 안 오면 포기한다 — 슬롯은 실패로 보고 항목을 만들지 않는다.
  static const _loadTimeout = Duration(seconds: 20);

  @override
  Future<LoadedNative?> load(AdPlacement placement, int widthDp) async {
    if (widthDp <= 0) return null;
    NativeAd? ad;
    try {
      final unitId = AppConfig.adUnitId(placement, isIos: Platform.isIOS);
      // 릴리스인데 .env가 비었다 — 광고를 띄우지 않는다.
      if (unitId == null) return null;

      await AdSdk.ensureInitialized();
      final nonPersonalized = await AdConsent.useNonPersonalized();

      final done = Completer<NativeAd?>();
      ad = NativeAd(
        adUnitId: unitId,
        // 요청에 넘기는 것은 비개인화 여부뿐이다. 이룸이·보호자 정보는 넘기지 않는다.
        request: AdRequest(nonPersonalizedAds: nonPersonalized),
        nativeTemplateStyle: NativeTemplateStyle(
          templateType: TemplateType.small,
        ),
        listener: NativeAdListener(
          onAdLoaded: (a) {
            if (!done.isCompleted) done.complete(a as NativeAd);
          },
          onAdFailedToLoad: (a, error) {
            AppLogger.error('네이티브 로드 실패 ${placement.name}', error);
            a.dispose();
            if (!done.isCompleted) done.complete(null);
          },
        ),
      );
      await ad.load();
      final loaded = await done.future.timeout(
        _loadTimeout,
        onTimeout: () {
          AppLogger.error('네이티브 로드 시간 초과 ${placement.name}', null);
          return null;
        },
      );
      if (loaded == null) {
        ad.dispose();
        return null;
      }
      return LoadedNative(
        height: _height,
        widget: SizedBox(
          height: _height,
          child: AdWidget(ad: loaded),
        ),
        dispose: loaded.dispose,
      );
    } catch (e, st) {
      // 광고는 보조 요소라 사용자에게 알리지 않는다. 다만 삼키지 않고 남긴다.
      AppLogger.error('네이티브 준비 실패 ${placement.name}', e, st);
      ad?.dispose();
      return null;
    }
  }
}
