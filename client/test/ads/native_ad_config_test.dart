import 'dart:io';

import 'package:elum/features/ads/data/ad_strip_loader.dart';
import 'package:flutter_test/flutter_test.dart';

/// 앱 ID가 비면 SDK가 시작하다 앱이 죽는다. 네이티브 설정이 빠지면 바로 알린다.
void main() {
  test('Android 매니페스트에 광고 앱 ID와 광고 ID 권한이 있다', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('com.google.android.gms.ads.APPLICATION_ID'));
    expect(manifest, contains(r'${admobAppId}'));
    expect(manifest, contains('com.google.android.gms.permission.AD_ID'));
  });

  test('iOS Info.plist에 광고 앱 ID·추적 안내 문구·SKAdNetwork가 있다', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('GADApplicationIdentifier'));
    expect(plist, contains(r'$(ELUM_ADMOB_APP_ID)'));
    expect(plist, contains('NSUserTrackingUsageDescription'));
    expect(plist, contains('SKAdNetworkItems'));
    expect(plist, isNot(contains('아이')));
  });

  // 팩토리 ID가 어긋나면 NativeAd 로드가 실패해 띠가 조용히 안 뜬다
  test('하단 띠 팩토리 ID가 Dart·Android·iOS에서 같다', () {
    const factoryId = 'elumStrip';
    expect(GoogleAdStripLoader.factoryId, factoryId);
    expect(
      File(
        'android/app/src/main/kotlin/kr/twinfang/elum/StripNativeAdFactory.kt',
      ).readAsStringSync(),
      contains('"$factoryId"'),
    );
    expect(
      File('ios/Runner/StripNativeAdFactory.swift').readAsStringSync(),
      contains('"$factoryId"'),
    );
    expect(
      File(
        'android/app/src/main/kotlin/kr/twinfang/elum/MainActivity.kt',
      ).readAsStringSync(),
      contains('registerNativeAdFactory'),
    );
    expect(
      File('ios/Runner/AppDelegate.swift').readAsStringSync(),
      contains('registerNativeAdFactory'),
    );
  });

  test('팩토리에 넘기는 색 옵션 키가 Kotlin·Swift와 같다', () {
    final options = GoogleAdStripLoader.customOptionsOf(
      const AdStripColors(
        background: 1,
        headline: 2,
        callToAction: 3,
        badgeBackground: 4,
        badgeText: 5,
      ),
    );
    final kotlin = File(
      'android/app/src/main/kotlin/kr/twinfang/elum/StripNativeAdFactory.kt',
    ).readAsStringSync();
    final swift = File(
      'ios/Runner/StripNativeAdFactory.swift',
    ).readAsStringSync();
    for (final key in options.keys) {
      expect(kotlin, contains('"$key"'), reason: 'Kotlin $key');
      expect(swift, contains('"$key"'), reason: 'Swift $key');
    }
    expect(options[GoogleAdStripLoader.badgeLabelKey], 'AD');
  });
}
