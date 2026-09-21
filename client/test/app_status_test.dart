import 'package:elum/core/app_status/app_status.dart';
import 'package:flutter_test/flutter_test.dart';

/// 점검 모드·강제 업데이트 판단 (이슈 #279).
void main() {
  group('버전 비교 — 문자열로 견주면 틀린다', () {
    test('1.10.0은 1.9.0보다 높다', () {
      // 문자열 비교면 '1.10.0' < '1.9.0'이 참이 되어, 최신 버전을 쓰는 사람에게
      // 업데이트를 요구하게 된다. 이것이 이 함수가 존재하는 이유다.
      expect(AppStatus.isLower('1.10.0', '1.9.0'), isFalse);
      expect(AppStatus.isLower('1.9.0', '1.10.0'), isTrue);
    });

    test('자리 수가 달라도 센다', () {
      expect(AppStatus.isLower('1.2', '1.2.1'), isTrue);
      expect(AppStatus.isLower('1.2.0', '1.2'), isFalse);
      expect(AppStatus.isLower('2', '1.99.99'), isFalse);
    });

    test('같으면 낮지 않다', () {
      expect(AppStatus.isLower('1.20.0', '1.20.0'), isFalse);
    });

    test('빌드 번호와 v 접두사는 떼고 본다', () {
      expect(AppStatus.isLower('1.2.0+45', '1.2.0'), isFalse);
      expect(AppStatus.isLower('v1.1.0', '1.2.0'), isTrue);
    });

    test('기준이 비어 있으면 막지 않는다', () {
      // 설정을 아직 안 넣었다는 뜻이다. 그것 때문에 사용자를 세우면 안 된다.
      expect(AppStatus.isLower('1.0.0', ''), isFalse);
      expect(AppStatus.isLower('', '9.9.9'), isFalse);
    });

    test('숫자로 읽히지 않으면 막지 않는다', () {
      // 관리자가 오타를 냈다고 앱이 멈추면 안 된다.
      expect(AppStatus.isLower('1.0.0', '이상한값'), isFalse);
      expect(AppStatus.isLower('abc', '1.0.0'), isFalse);
    });
  });

  group('서버 응답 읽기', () {
    test('형식이 달라도 예외를 던지지 않는다 — 앱이 못 뜨면 안 된다', () {
      expect(() => AppStatus.fromJson({}), returnsNormally);
      expect(() => AppStatus.fromJson({'ios': '문자열'}), returnsNormally);
      expect(() => AppStatus.fromJson({'maintenance': '참'}), returnsNormally);
    });

    test('모르는 값은 아무것도 막지 않는 상태가 된다', () {
      const unknown = AppStatus.unknown;
      expect(unknown.maintenance, isFalse);
      expect(unknown.requiresUpdate('1.0.0'), isFalse);
      expect(unknown.suggestsUpdate('1.0.0'), isFalse);
    });

    test('maintenance가 true가 아니면 전부 false로 본다', () {
      expect(AppStatus.fromJson({'maintenance': 'true'}).maintenance, isFalse);
      expect(AppStatus.fromJson({'maintenance': true}).maintenance, isTrue);
    });
  });

  group('업데이트 판단', () {
    const status = AppStatus(minVersion: '1.5.0', latestVersion: '1.20.0');

    test('최소치 미만이면 막는다', () {
      expect(status.requiresUpdate('1.4.9'), isTrue);
      expect(status.requiresUpdate('1.5.0'), isFalse);
    });

    test('최신보다 낮으면 권한다 — 막지는 않는다', () {
      expect(status.suggestsUpdate('1.19.0'), isTrue);
      expect(status.requiresUpdate('1.19.0'), isFalse);
    });

    test('버전을 읽지 못했으면 아무것도 막지 않는다', () {
      // PackageInfo 가 실패하면 빈 문자열이 온다.
      expect(status.requiresUpdate(''), isFalse);
      expect(status.suggestsUpdate(''), isFalse);
    });
  });
}
