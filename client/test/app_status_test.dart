import 'package:elum/core/app_status/app_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// 점검 모드·강제 업데이트 판단 (이슈 #279).
void main() {
  group('버전 비교 — 문자열로 견주면 틀린다', () {

    test('기준이 비어 있으면 막지 않는다', () {
      // 설정을 아직 안 넣었다는 뜻이다. 그것 때문에 사용자를 세우면 안 된다.
      expect(AppStatus.isLower('1.0.0', ''), isFalse);
      expect(AppStatus.isLower('', '9.9.9'), isFalse);
    });

  });

  group('서버 응답 읽기', () {
    test('형식이 달라도 예외를 던지지 않는다 — 앱이 못 뜨면 안 된다', () {
      expect(() => AppStatus.fromJson({}), returnsNormally);
      expect(() => AppStatus.fromJson({'ios': '문자열'}), returnsNormally);
      expect(() => AppStatus.fromJson({'maintenance': '참'}), returnsNormally);
    });

  });

  group('업데이트 판단', () {
    const status = AppStatus(minVersion: '1.5.0', latestVersion: '1.20.0');

    test('최소치 미만이면 막는다', () {
      expect(status.requiresUpdate('1.4.9'), isTrue);
      expect(status.requiresUpdate('1.5.0'), isFalse);
    });

    test('버전을 읽지 못했으면 아무것도 막지 않는다', () {
      // PackageInfo 가 실패하면 빈 문자열이 온다.
      expect(status.requiresUpdate(''), isFalse);
      expect(status.suggestsUpdate(''), isFalse);
    });
  });
}
