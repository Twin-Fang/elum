import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 광고 SDK 초기화 — 배너·네이티브·보상형이 함께 쓴다.
///
/// **처음 광고를 요청할 때 한 번만** 한다. 이룸이 전용 휴대폰은 보호자 화면을 열지
/// 않으므로 SDK 가 시작되지도 않는다. 실패하면 다음 요청에서 다시 시도할 수 있게
/// 캐시한 Future 를 비운다.
abstract final class AdSdk {
  static Future<void>? _init;

  static Future<void> ensureInitialized() => _init ??= () async {
    try {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          // 성인·선정 광고를 줄인다. 보호자 화면이라도 이룸이가 볼 수 있다.
          maxAdContentRating: MaxAdContentRating.pg,
        ),
      );
      await MobileAds.instance.initialize();
    } catch (_) {
      _init = null;
      rethrow;
    }
  }();
}
