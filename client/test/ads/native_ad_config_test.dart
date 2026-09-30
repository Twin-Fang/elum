import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 앱 ID가 비면 SDK가 시작하다 앱이 죽는다. 네이티브 설정이 빠지면 바로 알린다.
void main() {
  test('Android 매니페스트에 광고 앱 ID와 광고 ID 권한이 있다', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('com.google.android.gms.ads.APPLICATION_ID'));
    expect(manifest, contains(r'${admobAppId}'));
    expect(manifest, contains('com.google.android.gms.permission.AD_ID'));
  });

  test('Android 빌드가 앱 ID를 .env에서 읽고 비면 테스트 앱 ID를 쓴다', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('admobAppId'));
    expect(gradle, contains('ca-app-pub-3940256099942544~3347511713'));
  });

  test('iOS Info.plist에 광고 앱 ID·추적 안내 문구·SKAdNetwork가 있다', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('GADApplicationIdentifier'));
    expect(plist, contains(r'$(ELUM_ADMOB_APP_ID)'));
    expect(plist, contains('NSUserTrackingUsageDescription'));
    expect(plist, contains('SKAdNetworkItems'));
    expect(plist, isNot(contains('아이')));
  });

  test('iOS 시크릿 생성 스크립트가 앱 ID를 만들고 비면 테스트 앱 ID를 쓴다', () {
    final script = File('tool/gen_ios_secrets.sh').readAsStringSync();
    expect(script, contains('ELUM_ADMOB_APP_ID'));
    expect(script, contains('ca-app-pub-3940256099942544~1458002511'));
  });
}
