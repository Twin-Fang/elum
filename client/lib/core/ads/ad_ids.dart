/// 광고를 띄우는 자리. 형식이 아니라 **배치**로 나눠 광고 단위를 따로 둔다.
///
/// 배치마다 단위를 나눠 두면 콘솔에서 자리별 수익을 비교할 수 있다.
enum AdPlacement {
  bannerHome('BANNER_HOME'),
  bannerDrafts('BANNER_DRAFTS'),
  bannerSettings('BANNER_SETTINGS'),
  nativeHomePast('NATIVE_HOME_PAST'),
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
    AdPlacement.bannerDrafts: _banner,
    AdPlacement.bannerSettings: _banner,
    AdPlacement.nativeHomePast: (
      android: 'ca-app-pub-3940256099942544/2247696110',
      ios: 'ca-app-pub-3940256099942544/3986624511',
    ),
    AdPlacement.rewardedCredit: (
      android: 'ca-app-pub-3940256099942544/5224354917',
      ios: 'ca-app-pub-3940256099942544/1712485313',
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
    return value.isEmpty ? null : value;
  }
}
