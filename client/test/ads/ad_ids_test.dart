import 'package:elum/core/ads/ad_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String env(String key) => const {
        'ELUM_ADMOB_ANDROID_BANNER_HOME': 'ca-app-pub-real/1',
        'ELUM_ADMOB_IOS_BANNER_HOME': 'ca-app-pub-real/2',
      }[key] ??
      '';

  test('테스트 모드는 .env에 실제 ID가 있어도 Google 테스트 ID만 쓴다', () {
    final android = AdIds.resolve(
      placement: AdPlacement.bannerHome,
      isIos: false,
      useTestIds: true,
      readEnv: env,
    );
    final ios = AdIds.resolve(
      placement: AdPlacement.bannerHome,
      isIos: true,
      useTestIds: true,
      readEnv: env,
    );
    expect(android, 'ca-app-pub-3940256099942544/9214589741');
    expect(ios, 'ca-app-pub-3940256099942544/2435281174');
  });

  test('릴리스 모드는 .env 값을 쓴다', () {
    expect(
      AdIds.resolve(
        placement: AdPlacement.bannerHome,
        isIos: false,
        useTestIds: false,
        readEnv: env,
      ),
      'ca-app-pub-real/1',
    );
  });

  test('릴리스 모드에서 값이 비면 null — 광고를 띄우지 않는다', () {
    expect(
      AdIds.resolve(
        placement: AdPlacement.bannerSettings,
        isIos: true,
        useTestIds: false,
        readEnv: env,
      ),
      isNull,
    );
  });

  test('모든 배치에 두 플랫폼의 테스트 ID가 있다', () {
    for (final p in AdPlacement.values) {
      for (final ios in [true, false]) {
        final id = AdIds.resolve(
          placement: p,
          isIos: ios,
          useTestIds: true,
          readEnv: (_) => '',
        );
        expect(id, startsWith('ca-app-pub-3940256099942544/'));
      }
    }
  });
}
