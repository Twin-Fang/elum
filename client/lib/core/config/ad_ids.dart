/// 광고를 띄우는 자리. 형식이 아니라 **배치**로 나눠 광고 단위를 따로 둔다.
///
/// 배치마다 단위를 나눠 두면 콘솔에서 자리별 수익을 비교할 수 있다.
enum AdPlacement {
  bannerHome('BANNER_HOME'),

  /// 보호자 홈 지난 일과 목록 사이 한 칸. 하단 배너와 별개로 노출을 늘린다.
  bannerHomeMiddle('BANNER_HOME_MIDDLE'),
  bannerDrafts('BANNER_DRAFTS'),
  bannerSettings('BANNER_SETTINGS'),

  /// 화면 맨 아래 한 줄 네이티브 띠. 하단 띠를 쓰는 모든 화면이 단위 하나를 함께 쓴다.
  nativeStrip('NATIVE_STRIP'),
  rewardedCredit('REWARDED_CREDIT');

  const AdPlacement(this.envSuffix);

  /// `.env` 키의 뒷부분. `ELUM_ADMOB_{IOS|ANDROID}_{envSuffix}`.
  final String envSuffix;
}

/// 광고 단위 ID 해석.
///
/// ⚠️ **테스트 모드면 `.env`를 읽지 않는다.** 개발 중 실제 광고를 누르면 AdMob
/// 계정이 정지될 수 있다. 실수로 실제 ID가 `.env`에 있어도 개발·테스트 빌드에서는
/// 절대 쓰이지 않게 이 함수 안에서 막는다.
abstract final class AdIds {
  static const _banner = (
    android: 'ca-app-pub-3940256099942544/9214589741',
    ios: 'ca-app-pub-3940256099942544/2435281174',
  );

  /// Google이 공개한 공식 테스트 광고 단위.
  static const _testIds = <AdPlacement, ({String android, String ios})>{
    AdPlacement.bannerHome: _banner,
    AdPlacement.bannerHomeMiddle: _banner,
    AdPlacement.bannerDrafts: _banner,
    AdPlacement.bannerSettings: _banner,
    AdPlacement.nativeStrip: (
      android: 'ca-app-pub-3940256099942544/2247696110',
      ios: 'ca-app-pub-3940256099942544/3986624511',
    ),
    AdPlacement.rewardedCredit: (
      android: 'ca-app-pub-3940256099942544/5224354917',
      ios: 'ca-app-pub-3940256099942544/1712485313',
    ),
  };

  /// 운영 광고 단위 (AdMob 콘솔 `native_strip_bottom`). `.env` 값이 있으면 그쪽이 우선한다.
  /// 비어 있으면 릴리스에서 광고를 요청하지 않는다.
  static const _releaseDefaults = <AdPlacement, ({String android, String ios})>{
    AdPlacement.nativeStrip: (
      android: 'ca-app-pub-2025665624324395/4054407957',
      ios: 'ca-app-pub-2025665624324395/5242621687',
    ),
  };

  /// 릴리스에서 값이 비어 있으면 null — 호출한 쪽은 광고를 띄우지 않는다.
  static String? resolve({
    required AdPlacement placement,
    required bool isIos,
    required bool useTestIds,
    required String Function(String key) readEnv,
  }) {
    if (useTestIds) {
      final ids = _testIds[placement]!;
      return isIos ? ids.ios : ids.android;
    }
    final key =
        'ELUM_ADMOB_${isIos ? 'IOS' : 'ANDROID'}_${placement.envSuffix}';
    final value = readEnv(key).trim();
    if (value.isNotEmpty) return value;
    final fallback = _releaseDefaults[placement];
    if (fallback == null) return null;
    final fallbackId = isIos ? fallback.ios : fallback.android;
    return fallbackId.isEmpty ? null : fallbackId;
  }
}
