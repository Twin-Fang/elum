import 'package:elum/core/config/ad_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String env(String key) => const {
        'ELUM_ADMOB_ANDROID_BANNER_HOME': 'ca-app-pub-real/1',
        'ELUM_ADMOB_IOS_BANNER_HOME': 'ca-app-pub-real/2',
      }[key] ??
      '';

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

}
