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

  // --- 릴리스(R8) 전용 결함 (#446) ---
  //
  // debug 빌드는 R8 을 돌리지 않아 위 태스크 문제를 고쳐도 **릴리스에서만** 네이버 로그인이 죽었다
  // (2026-09-29 실측). 네이버가 인증 코드를 주고 앱까지 돌려줘도 SDK 의 토큰 교환이
  // `ClassCastException: java.lang.Class cannot be cast to java.lang.reflect.ParameterizedType`
  // 으로 실패하고 화면에는 E-AUTH-SDK 가 떴다. SDK 가 쓰는 Retrofit(+코루틴)이 제네릭 시그니처를
  // 리플렉션으로 읽는데 R8 풀 모드가 그 정보를 지운다. 규칙 파일을 읽어 다시 빠지지 못하게 한다.
  group('R8 규칙 — 릴리스 네이버 로그인', () {
    final rules = File('android/app/proguard-rules.pro')
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('#'))
        .join('\n');

    test('제네릭 시그니처를 남긴다 — Retrofit 이 반환 타입을 리플렉션으로 읽는다', () {
      expect(rules, contains('-keepattributes Signature'));
    });

    test('코루틴 Continuation 을 지킨다 — suspend 메서드 반환 타입이 타입 인자에 있다', () {
      expect(rules, contains('kotlin.coroutines.Continuation'));
    });

    test('Retrofit 서비스 인터페이스와 Response 를 지킨다 — 풀 모드가 Proxy 구현을 못 봐 지운다', () {
      expect(rules, contains('@retrofit2.http.*'));
      expect(rules, contains('retrofit2.Response'));
    });

    test('네이버 SDK 자체 규칙이 남아 있다', () {
      expect(rules, contains('com.navercorp.nid'));
    });
  });
}
