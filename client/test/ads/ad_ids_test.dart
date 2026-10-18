import 'package:elum/core/config/ad_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String env(String key) =>
      const {
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

  // 릴리스에서 테스트 ID로 새면 안 된다. .env가 비면 운영 기본값을 쓴다
  test('하단 띠 단위는 릴리스에서 운영 ID, 테스트 모드는 Google 네이티브 테스트 ID', () {
    String? resolve({required bool isIos, required bool useTestIds}) =>
        AdIds.resolve(
          placement: AdPlacement.nativeStrip,
          isIos: isIos,
          useTestIds: useTestIds,
          readEnv: env,
        );
    expect(
      resolve(isIos: false, useTestIds: false),
      'ca-app-pub-2025665624324395/4054407957',
    );
    expect(
      resolve(isIos: true, useTestIds: false),
      'ca-app-pub-2025665624324395/5242621687',
    );
    expect(
      resolve(isIos: false, useTestIds: true),
      'ca-app-pub-3940256099942544/2247696110',
    );
    expect(
      resolve(isIos: true, useTestIds: true),
      'ca-app-pub-3940256099942544/3986624511',
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
