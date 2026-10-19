
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/features/ads/data/ad_consent.dart';

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

  test('이미 답한 기기에서는 다시 묻지 않는다', () async {
    current = TrackingStatus.denied;
    await AdConsent.requestOnLaunch();
    expect(requests, 0);
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

  test('요청이 예외를 내도 앱은 죽지 않고 광고는 비개인화로 간다', () async {
    AdConsent.requestAuthorization = () async => throw StateError('ATT 실패');
    await AdConsent.requestOnLaunch();
    expect(await AdConsent.useNonPersonalized(), isTrue);
  });

}
