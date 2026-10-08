import 'package:elum/core/storage/guardian_lock_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/storage/shared_prefs_storage.dart';

/// `clearAll()`은 개발자 도구의 "온보딩 초기화"가 쓰는 동작이다.
///
/// 일부 값만 지워지면 어중간한 상태가 남아 온보딩이 정상 진행되지 않는다.
/// 5개 값이 전부 비워지는지 고정한다. (이슈 #13)
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
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
      expect(await storage.hasPin(), isFalse);
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

  // 다중 보호자 (#362). 고른 이룸이는 이 휴대폰·이 로그인에만 속한다.
  group('선택한 이룸이', () {
    test('저장하고 지운다', () async {
      final storage = InMemoryStorage();
      expect(storage.selectedProfileId, isNull);

      await storage.setSelectedProfileId('p-1');
      expect(storage.selectedProfileId, 'p-1');

      await storage.clearSelectedProfileId();
      expect(storage.selectedProfileId, isNull);
    });

    test('로그아웃(clearAll)과 새 계정 정리(clearChildProfile)가 함께 지운다', () async {
      // 다른 계정으로 들어왔을 때 옛 이룸이 id 가 헤더에 실리면 서버가 403 을 준다.
      final a = InMemoryStorage();
      await a.setSelectedProfileId('p-1');
      await a.clearAll();
      expect(a.selectedProfileId, isNull);

      final b = InMemoryStorage();
      await b.setSelectedProfileId('p-1');
      await b.clearChildProfile();
      expect(b.selectedProfileId, isNull);
    });

    test('오늘 일과 캐시를 따로 지울 수 있다 (이룸이를 바꿀 때)', () async {
      // 오프라인이면 캐시를 보여 주는데, 다른 이룸이의 일과가 남아 있으면 안 된다 (E44).
      final storage = InMemoryStorage();
      await storage.setCachedTodayRoutinesJson('[]');
      expect(storage.cachedTodayRoutinesJson, isNotNull);

      await storage.clearCachedTodayRoutines();
      expect(storage.cachedTodayRoutinesJson, isNull);
    });
  });

  // 이룸이 휴대폰의 연결이 밖에서 끊겼다는 표식 (#363). 연결 화면이 `연결이 끊어졌어요`를 말하는 근거다.
  group('이룸이 휴대폰 연결 끊김 표식', () {
    test('처음에는 서 있지 않고, 세우고 내릴 수 있다 (메모리)', () async {
      final storage = InMemoryStorage();
      expect(storage.isElumiLinkLost, isFalse);

      await storage.setElumiLinkLost(true);
      expect(storage.isElumiLinkLost, isTrue);

      await storage.setElumiLinkLost(false);
      expect(storage.isElumiLinkLost, isFalse);
    });

    test('앱을 다시 켜도 남는다 (SharedPreferences)', () async {
      SharedPreferences.setMockInitialValues({});
      final first = await SharedPrefsStorage.create(lock: GuardianLockStore(installationId: 'test-install'));
      await first.setElumiLinkLost(true);

      // 같은 저장소를 새로 열어 읽는다 — 앱 재시작과 같다
      final reopened = await SharedPrefsStorage.create(lock: GuardianLockStore(installationId: 'test-install'));
      expect(reopened.isElumiLinkLost, isTrue);
    });

    test(
      '아이 정보만 지우는 정리(clearChildProfile)는 표식도 이룸이 휴대폰 표식도 건드리지 않는다',
      () async {
        final storage = InMemoryStorage(elumiDevice: true);
        await storage.setElumiLinkLost(true);
        await storage.setNickname('하늘이');

        await storage.clearChildProfile();

        expect(storage.nickname, isNull);
        expect(
          storage.isElumiDevice,
          isTrue,
          reason: '이 휴대폰은 여전히 이룸이 휴대폰이라 연결 화면으로 간다',
        );
        expect(storage.isElumiLinkLost, isTrue);
      },
    );

    test('clearAll 은 표식도 함께 지운다 — 완전히 처음 상태로 돌아간다', () async {
      SharedPreferences.setMockInitialValues({});
      final shared = await SharedPrefsStorage.create(lock: GuardianLockStore(installationId: 'test-install'));
      final memory = InMemoryStorage(elumiDevice: true);
      for (final s in [shared, memory]) {
        await s.setElumiLinkLost(true);
        await s.clearAll();
        expect(s.isElumiLinkLost, isFalse);
      }
    });
  });
}
