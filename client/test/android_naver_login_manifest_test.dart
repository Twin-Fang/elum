import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 안드로이드 네이버 로그인 설정 (#379).
///
/// **`MainActivity` 에 `android:taskAffinity=""` 가 있으면 네이버 로그인이 도돌이표가 된다.**
/// Flutter 기본 템플릿이 이 줄을 넣어 두는데, 그러면 네이버 SDK 의 결과 수신 Activity
/// (`NidOAuthCustomTabActivity`)가 `MainActivity` 와 다른 태스크에 놓인다. 실기기(에뮬레이터)
/// 실측(2026-09-29): 동의(OK)를 누르면 네이버는 인증 코드를 정상 발급하고
/// `intent://authorize/#Intent;…;S.code=…;S.state=…;end` 로 앱에 돌려주는데, SDK 가 그
/// 결과를 못 받아(`getDecodedString() | str : null`) 같은 동의 화면을 다시 연다.
/// 줄을 빼면 앱으로 돌아와 토큰이 저장되고 다음 화면으로 넘어간다.
///
/// `flutter_naver_login` 안내도 "task affinity 가 필요하지 않으면 `android:taskAffinity=""` 를
/// 제거하라"고 하고, `MainActivity` 는 `FlutterFragmentActivity` 여야 한다.
///
/// 위젯 테스트로는 이 결함을 볼 수 없다(네이티브 태스크 문제다). 그래서 **설정 파일을 직접 읽어**
/// 다시 들어오지 못하게 한다 — 누가 템플릿 기본값을 되돌려도 여기서 걸린다.
void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  final mainActivity = File(
    'android/app/src/main/kotlin/kr/twinfang/elum/MainActivity.kt',
  ).readAsStringSync();

  /// XML 주석을 걷어낸 매니페스트. 주석에 `taskAffinity` 라는 낱말이 남아 있어도
  /// 설정으로 오인하지 않게 한다.
  final manifestBody = manifest.replaceAll(
    RegExp(r'<!--.*?-->', dotAll: true),
    '',
  );

  /// `<activity … android:name=".MainActivity" …>` 태그 한 덩어리.
  String activityTag() {
    final m = RegExp(
      r'<activity\b[^>]*android:name="\.MainActivity"[^>]*>',
      dotAll: true,
    ).firstMatch(manifestBody);
    expect(m, isNotNull, reason: 'MainActivity 선언을 찾지 못했다');
    return m!.group(0)!;
  }

  test('MainActivity 에 taskAffinity 가 없다 — 네이버 로그인 도돌이표 방지', () {
    expect(
      activityTag(),
      isNot(contains('taskAffinity')),
      reason: '네이버 SDK 결과 수신 Activity 가 다른 태스크에 놓여 인증 결과를 못 받는다 (#379)',
    );
  });

  test('MainActivity 는 FlutterFragmentActivity 다 — 네이버 SDK 요구', () {
    expect(mainActivity, contains('FlutterFragmentActivity'));
    expect(mainActivity, isNot(contains(': FlutterActivity()')));
  });

  test('네이버 SDK 설정 세 값이 매니페스트에 있다', () {
    for (final key in ['clientId', 'clientSecret', 'clientName']) {
      expect(
        manifestBody,
        contains('com.naver.sdk.$key'),
        reason: '$key 가 빠지면 SDK 가 초기화되지 않는다',
      );
    }
  });
}
