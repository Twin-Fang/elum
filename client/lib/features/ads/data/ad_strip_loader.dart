import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/config/ad_ids.dart';
import '../../../core/config/app_config.dart';
import '../../../core/logger/app_logger.dart';
import 'ad_banner_loader.dart' show LoadedBanner;
import 'ad_consent.dart';
import 'ad_sdk.dart';

/// 하단 띠 색 (ARGB 정수). 앱 색 토큰이 로드 때 네이티브 팩토리로 넘어간다.
class AdStripColors {
  const AdStripColors({
    required this.background,
    required this.headline,
    required this.callToAction,
    required this.badgeBackground,
    required this.badgeText,
  });

  final int background;
  final int headline;

  /// 행동 문구와 > 화살표 공통
  final int callToAction;
  final int badgeBackground;
  final int badgeText;

  @override
  bool operator ==(Object other) =>
      other is AdStripColors &&
      other.background == background &&
      other.headline == headline &&
      other.callToAction == callToAction &&
      other.badgeBackground == badgeBackground &&
      other.badgeText == badgeText;

  @override
  int get hashCode => Object.hash(
    background,
    headline,
    callToAction,
    badgeBackground,
    badgeText,
  );
}

/// 하단 띠를 불러온다. 테스트는 이것을 가짜로 바꿔 SDK를 띄우지 않는다.
abstract interface class AdStripLoader {
  /// 실패·미지원이면 null. **예외를 던지지 않는다.**
  Future<LoadedBanner?> load(AdPlacement placement, AdStripColors colors);
}

final adStripLoaderProvider = Provider<AdStripLoader>(
  (ref) => GoogleAdStripLoader(),
);

/// google_mobile_ads 구현: 단위 ID 확인 > SDK 초기화 > 동의 확인 > 한 줄 네이티브 광고 요청
///
/// SDK는 **처음 요청할 때** 초기화한다. 이룸이 전용 휴대폰은 보호자 화면을
/// 열지 않으므로 SDK가 시작되지도 않는다. 뷰는 앱 네이티브 팩토리([factoryId])가 그린다.
class GoogleAdStripLoader implements AdStripLoader {
  /// 띠 높이 (dp). 네이티브 레이아웃이 이 높이에 한 줄로 그린다.
  static const stripHeight = 44.0;

  // MainActivity.kt 의 registerNativeAdFactory · AppDelegate.swift 의 등록 ID 와 같은 값
  static const factoryId = 'elumStrip';

  // customOptions 키: StripNativeAdFactory.kt · StripNativeAdFactory.swift 와 같은 값
  static const backgroundColorKey = 'backgroundColor';
  static const headlineColorKey = 'headlineColor';
  static const callToActionColorKey = 'callToActionColor';
  static const badgeBackgroundColorKey = 'badgeBackgroundColor';
  static const badgeTextColorKey = 'badgeTextColor';
  static const badgeLabelKey = 'badgeLabel';

  /// 광고 표시 배지 문구 (정책상 필수)
  static const badgeLabel = 'AD';

  // 이 시간 안에 안 오면 포기 > 띠 없음
  static const _loadTimeout = Duration(seconds: 20);

  /// 띠 색 > 팩토리 옵션 (색은 ARGB 정수)
  static Map<String, Object> customOptionsOf(AdStripColors colors) => {
    backgroundColorKey: colors.background,
    headlineColorKey: colors.headline,
    callToActionColorKey: colors.callToAction,
    badgeBackgroundColorKey: colors.badgeBackground,
    badgeTextColorKey: colors.badgeText,
    badgeLabelKey: badgeLabel,
  };

  @override
  Future<LoadedBanner?> load(
    AdPlacement placement,
    AdStripColors colors,
  ) async {
    NativeAd? ad;
    try {
      // 띠는 배치와 무관하게 단위 하나를 쓴다. 배치는 로그 구분용이다.
      final unitId = AppConfig.adUnitId(
        AdPlacement.nativeStrip,
        isIos: Platform.isIOS,
      );
      // 릴리스인데 .env가 비었다 — 광고를 띄우지 않는다.
      if (unitId == null) return null;

      await AdSdk.ensureInitialized();
      final nonPersonalized = await AdConsent.useNonPersonalized();

      final done = Completer<NativeAd?>();
      ad = NativeAd(
        adUnitId: unitId,
        factoryId: factoryId,
        customOptions: customOptionsOf(colors),
        // 요청에 넘기는 것은 비개인화 여부뿐이다. 이룸이·보호자 정보는 넘기지 않는다.
        request: AdRequest(nonPersonalizedAds: nonPersonalized),
        listener: NativeAdListener(
          onAdLoaded: (a) {
            if (!done.isCompleted) done.complete(a as NativeAd);
          },
          onAdFailedToLoad: (a, error) {
            AppLogger.error('띠 광고 로드 실패 ${placement.name}', error);
            if (!done.isCompleted) done.complete(null);
          },
        ),
      );
      await ad.load();
      final loaded = await done.future.timeout(
        _loadTimeout,
        onTimeout: () {
          AppLogger.error('띠 광고 로드 시간 초과 ${placement.name}', null);
          return null;
        },
      );
      if (loaded == null) {
        // 실패·시간 초과 공통 해제
        ad.dispose();
        return null;
      }
      return LoadedBanner(
        height: stripHeight,
        widget: SizedBox(
          height: stripHeight,
          child: AdWidget(ad: loaded),
        ),
        dispose: loaded.dispose,
      );
    } catch (e, st) {
      // 광고는 보조 요소라 사용자에게 알리지 않는다. 다만 삼키지 않고 남긴다.
      AppLogger.error('띠 광고 준비 실패 ${placement.name}', e, st);
      ad?.dispose();
      return null;
    }
  }
}
