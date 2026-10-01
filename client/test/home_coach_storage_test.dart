import 'package:elum/core/storage/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 홈 코치마크를 봤다는 기록은 계정이 아니라 휴대폰에 속한다 (이슈 #505).
///
/// 로그아웃(`clearAll`)·이룸이 정보 초기화(`clearChildProfile`)로 지워지면, 로그아웃했다
/// 들어올 때마다 안내가 처음부터 다시 나온다.
void main() {
  group('SharedPrefsStorage', () {
    late LocalStorage storage;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await SharedPrefsStorage.create();
    });

    test('처음엔 안 본 것이다', () {
      expect(storage.isHomeCoachSeen, isFalse);
    });

    test('봤다고 남기면 읽힌다', () async {
      await storage.setHomeCoachSeen(true);
      expect(storage.isHomeCoachSeen, isTrue);
    });

    test('로그아웃(clearAll)해도 남는다', () async {
      await storage.setHomeCoachSeen(true);
      await storage.clearAll();
      expect(storage.isHomeCoachSeen, isTrue);
    });

    test('이룸이 정보를 지워도(clearChildProfile) 남는다', () async {
      await storage.setHomeCoachSeen(true);
      await storage.clearChildProfile();
      expect(storage.isHomeCoachSeen, isTrue);
    });
  });

  group('InMemoryStorage', () {
    test('기본은 본 것으로 둔다 — 다른 화면 테스트를 가리지 않으려고', () {
      expect(InMemoryStorage().isHomeCoachSeen, isTrue);
    });

    test('안 본 상태로 시작해 clearAll 해도 남는다', () async {
      final s = InMemoryStorage(homeCoachSeen: false);
      expect(s.isHomeCoachSeen, isFalse);
      await s.setHomeCoachSeen(true);
      await s.clearAll();
      expect(s.isHomeCoachSeen, isTrue);
    });
  });
}
