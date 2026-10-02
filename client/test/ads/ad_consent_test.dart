import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/core/ads/ad_consent.dart';

/// ATT 는 광고 요청이 아니라 앱 시작 직후 묻는다 (#519 심사 2.1 리젝).
void main() {
  late int requests;
  late TrackingStatus current;

  setUp(() {
    requests = 0;
    current = TrackingStatus.notDetermined;
    AdConsent.isIos = () => true;
    AdConsent.readStatus = () async => current;
    AdConsent.requestAuthorization = () async {
      requests++;
      // 사용자가 허용했다고 본다.
      current = TrackingStatus.authorized;
      return current;
    };
    AdConsent.waitUntilActive = () async {};
    AdConsent.settle = Duration.zero;
  });

  tearDown(AdConsent.resetForTest);

  test('앱 시작 시 아직 답하지 않았으면 팝업을 한 번 요청한다', () async {
    await AdConsent.requestOnLaunch();
    expect(requests, 1);
  });

  test('이미 답한 휴대폰에서는 다시 묻지 않는다', () async {
    current = TrackingStatus.denied;
    await AdConsent.requestOnLaunch();
    expect(requests, 0);
  });

  test('Android 는 ATT 가 없어 묻지 않고 개인화 기본이다', () async {
    AdConsent.isIos = () => false;
    await AdConsent.requestOnLaunch();
    expect(requests, 0);
    expect(await AdConsent.useNonPersonalized(), isFalse);
  });

  test('시작 요청과 광고 로더가 동시에 불러도 팝업은 한 번만 요청한다', () async {
    final results = await Future.wait([
      AdConsent.requestOnLaunch().then((_) => true),
      AdConsent.useNonPersonalized(),
      AdConsent.useNonPersonalized(),
    ]);
    expect(requests, 1);
    // 허용했으므로 개인화(비개인화 false)로 요청한다.
    expect(results[1], isFalse);
    expect(results[2], isFalse);
  });

  test('시작 때 이미 물었다면 광고 로더는 답만 읽고 다시 묻지 않는다', () async {
    await AdConsent.requestOnLaunch();
    expect(await AdConsent.useNonPersonalized(), isFalse);
    expect(requests, 1);
  });

  test('거부하면 광고는 비개인화로 간다', () async {
    current = TrackingStatus.denied;
    expect(await AdConsent.useNonPersonalized(), isTrue);
  });

  test('요청이 예외를 내도 앱은 죽지 않고 광고는 비개인화로 간다', () async {
    AdConsent.requestAuthorization = () async => throw StateError('ATT 실패');
    await AdConsent.requestOnLaunch();
    expect(await AdConsent.useNonPersonalized(), isTrue);
  });

  test('요청이 실패해도 다음 요청에서 다시 시도할 수 있다', () async {
    var calls = 0;
    AdConsent.requestAuthorization = () async {
      calls++;
      if (calls == 1) throw StateError('첫 요청 실패');
      current = TrackingStatus.authorized;
      return current;
    };
    await AdConsent.requestOnLaunch();
    expect(await AdConsent.useNonPersonalized(), isFalse);
    expect(calls, 2);
  });

  test('앱 시작 코드가 ATT 요청을 부르고, 이룸이 휴대폰은 건너뛴다', () {
    final app = File('lib/app.dart').readAsStringSync();
    expect(app, contains('AdConsent.requestOnLaunch()'));
    expect(app, contains('isElumiDevice) return;'));
  });
}
