import 'package:elum/core/storage/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// `clearAll()`은 개발자 도구의 "온보딩 초기화"가 쓰는 동작이다.
///
/// 일부 값만 지워지면 어중간한 상태가 남아 온보딩이 정상 진행되지 않는다.
/// 5개 값이 전부 비워지는지 고정한다. (이슈 #13)
void main() {
  group('InMemoryStorage.clearAll', () {
    test('저장한 값 5개를 모두 지운다', () async {
      final storage = InMemoryStorage();
      await storage.setNickname('하늘이');
      await storage.setGoals(['PREPARE_ITEMS', 'PREPARE_NEW']);
      await storage.setCharacter('FOX');
      await storage.setPin('1234');
      await storage.setOnboardingCompleted(true);

      await storage.clearAll();

      expect(storage.nickname, isNull);
      expect(storage.goals, isEmpty);
      expect(storage.character, isNull);
      expect(await storage.getPin(), isNull);
      expect(storage.isOnboardingCompleted, isFalse);
    });

    test('초기화 후에는 온보딩 미완료 상태가 된다', () async {
      // 시작 화면이 이 값으로 온보딩/홈 분기를 판단한다.
      // false가 아니면 초기화해도 홈으로 다시 튕긴다.
      final storage = InMemoryStorage(onboardingCompleted: true);

      await storage.clearAll();

      expect(storage.isOnboardingCompleted, isFalse);
    });

    test('비어 있는 상태에서 호출해도 죽지 않는다', () async {
      final storage = InMemoryStorage();

      await expectLater(storage.clearAll(), completes);
    });
  });
}
