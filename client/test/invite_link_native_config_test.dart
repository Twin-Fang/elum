import 'dart:io';

import 'package:elum/features/profile/domain/invite_link.dart';
import 'package:flutter_test/flutter_test.dart';

/// 초대 링크가 앱을 열 수 있게 하는 **네이티브 설정** (#365).
///
/// 위젯 테스트로는 OS 가 주소를 앱으로 넘기는 길을 볼 수 없다. 그래서 설정 파일을 직접 읽어 앱 주소
/// (`elum://invite`) 가 두 플랫폼에서 선언돼 있는지 고정한다 — 누가 필터를 지워도 여기서 걸린다.
///
/// 웹 링크(`https://twin-fang.github.io/elum/invite/`)를 OS 가 앱으로 직접 열어 주는 Android App Links·
/// iOS Universal Links 는 **여기서 선언하지 않는다.** 도메인 루트(`twin-fang.github.io`)에 검증 파일을
/// 둘 수 있어야 하는데 지금 사이트는 하위 경로(`/elum/`)이고, iOS 는 Associated Domains 기능을 개발자
/// 계정에서 켜야 서명이 깨지지 않는다. 선언만 해 두고 검증이 안 되면 효과 없이 설정만 늘어난다.
/// 대신 안내 페이지의 `앱에서 열기` 가 앱 주소를 부른다.
void main() {
  /// XML 주석을 걷어낸 매니페스트 — 주석 속 낱말을 설정으로 오인하지 않는다.
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  final plist = File(
    'ios/Runner/Info.plist',
  ).readAsStringSync().replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  /// `MainActivity` 요소 전체.
  String mainActivity() {
    final m = RegExp(
      r'<activity\b[^>]*android:name="\.MainActivity".*?</activity>',
      dotAll: true,
    ).firstMatch(manifest);
    expect(m, isNotNull, reason: 'MainActivity 선언을 찾지 못했다');
    return m!.group(0)!;
  }

  test('안드로이드: MainActivity 가 elum://invite 를 받는다', () {
    final filters = RegExp(
      r'<intent-filter\b.*?</intent-filter>',
      dotAll: true,
    ).allMatches(mainActivity()).map((m) => m.group(0)!).toList();

    final invite = filters.where(
      (f) =>
          f.contains('android:scheme="${InviteLink.appScheme}"') &&
          f.contains('android:host="invite"'),
    );
    expect(invite, hasLength(1), reason: '초대 링크용 인텐트 필터가 하나여야 한다');

    final f = invite.single;
    expect(f, contains('android.intent.action.VIEW'));
    // 브라우저(안내 페이지의 앱에서 열기 버튼)가 부르려면 BROWSABLE 이 있어야 한다
    expect(f, contains('android.intent.category.BROWSABLE'));
    expect(f, contains('android.intent.category.DEFAULT'));
  });

  test('안드로이드: 런처 필터는 그대로다 — 초대 필터가 시작 화면을 가리지 않는다', () {
    expect(mainActivity(), contains('android.intent.action.MAIN'));
    expect(mainActivity(), contains('android.intent.category.LAUNCHER'));
  });

  test('안드로이드: 호스트 없는 넓은 elum 필터가 없다 — 다른 elum:// 주소를 가로채지 않는다', () {
    final broad = RegExp(
      r'<data\b[^>]*android:scheme="elum"(?![^>]*android:host)[^>]*/>',
    );
    expect(broad.hasMatch(mainActivity()), isFalse);
  });

  test('iOS: elum 스킴이 등록돼 있다 (네이버 로그인 콜백과 같은 스킴을 함께 쓴다)', () {
    final schemes = RegExp(
      r'<key>CFBundleURLSchemes</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist);
    expect(schemes, isNotNull);
    expect(
      schemes!.group(1),
      contains('<string>${InviteLink.appScheme}</string>'),
    );
  });

  test('앱 주소 스킴은 두 플랫폼이 같은 값을 쓴다', () {
    expect(InviteLink.appScheme, 'elum');
    expect(InviteLink.appUrl('A7K3M9'), startsWith('elum://invite'));
  });
}
