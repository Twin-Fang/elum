import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/features/profile/application/profile_session.dart';
import 'package:elum/features/profile/domain/profile_summary.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dio.dart';
import 'helpers/profile_fixtures.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';

/// 이룸이가 없는 보호자가 이룸이를 다시 등록할 때 `POST /api/member/profile` 을 먼저 부른다 (#362).
/// 서버는 이룸이 없이 이름 저장을 404 PROFILE_NOT_FOUND 로 막는다.
void main() {
  const created = ProfileSummary(id: 'p-new');

  group('MemberRepository.createProfile', () {
    MemberRepository repoWith(Map<String, Object?> routes) {
      final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
        ..httpClientAdapter = FakeAdapter(routes);
      return MemberRepository(dio: dio);
    }

    test('POST /api/member/profile 응답의 새 이룸이를 회원 정보로 읽는다', () async {
      final adapter = FakeAdapter({
        'POST /api/member/profile': {
          'totalStars': 0,
          'supportGoals': <String>[],
          'profiles': [
            {'id': 'p-new'},
          ],
        },
      });
      final repo = MemberRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://test.local'))
          ..httpClientAdapter = adapter,
      );

      final result = await repo.createProfile();

      expect(adapter.calls, ['POST /api/member/profile']);
      expect(result.isOk, isTrue);
      expect(result.value!.profilesKnown, isTrue);
      expect(result.value!.profiles.single.id, 'p-new');
    });

    test('이룸이 목록이 없는 응답은 성공으로 읽지 않는다 — 어느 이룸이인지 모른다', () async {
      final repo = repoWith({
        'POST /api/member/profile': {'totalStars': 0},
      });

      final result = await repo.createProfile();

      expect(result.isOk, isFalse);
    });

    test('403(이룸이 휴대폰)은 실패이고 경로 없음이 아니다', () async {
      final repo = repoWith({
        'POST /api/member/profile': const FakeHttpError(
          403,
          errorCode: 'DEVICE_LINK_FORBIDDEN_FOR_ELUMI',
          errorMessage: '이룸이 휴대폰은 할 수 없어요',
        ),
      });

      final result = await repo.createProfile();

      expect(result.isOk, isFalse);
      expect(result.failure!.server!.statusCode, 403);
      expect(MemberRepository.isRouteMissing(result.failure!), isFalse);
    });

    test('코드 없는 404·405 는 이 경로를 모르는 옛 서버다', () async {
      for (final status in [404, 405]) {
        final repo = repoWith({
          'POST /api/member/profile': FakeHttpError(status),
        });
        final result = await repo.createProfile();
        expect(MemberRepository.isRouteMissing(result.failure!), isTrue);
      }
    });

    test('코드가 붙은 404 는 경로 없음이 아니다 — 경로가 있는 서버의 말이다', () async {
      final repo = repoWith({
        'POST /api/member/profile': const FakeHttpError(
          404,
          errorCode: 'PROFILE_NOT_FOUND',
        ),
      });
      final result = await repo.createProfile();
      expect(MemberRepository.isRouteMissing(result.failure!), isFalse);
    });

    test('서버에 닿지 못하면 실패다', () async {
      final repo = repoWith({'POST /api/member/profile': const FakeOffline()});
      final result = await repo.createProfile();
      expect(result.failure!.isUnreachable, isTrue);
    });
  });

  group('ProfileSessionNotifier.ensureProfile', () {
    late InMemoryStorage storage;
    late _FakeMemberRepo repo;
    late Member shown;
    var memberFetches = 0;

    ProviderContainer build() {
      final c = ProviderContainer(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          memberRepositoryProvider.overrideWithValue(repo),
          memberProvider.overrideWith((ref) async {
            memberFetches++;
            return shown;
          }),
          // 이룸이 없음 처리가 일과 목록을 다시 받는다 — 네트워크로 나가지 않게 막는다.
          todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          pastRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          routineSuggestionsProvider.overrideWith((ref) async => const []),
        ],
      );
      addTearDown(c.dispose);
      c.listen(profileSessionProvider, (_, _) {});
      return c;
    }

    // 회원 정보가 들어와 이룸이 없음 처리가 끝날 때까지 기다린다.
    Future<void> settle(ProviderContainer c) async {
      await c.read(memberProvider.future);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    setUp(() {
      storage = InMemoryStorage(onboardingCompleted: false, pin: '1234');
      repo = _FakeMemberRepo()..createResult = Attempt.ok(memberWith([created]));
      shown = const Member(profiles: [], profilesKnown: true);
      memberFetches = 0;
    });

    test('이룸이가 없다고 확실할 때 만들고 그 이룸이를 고른다', () async {
      final c = build();
      await settle(c);
      // 입력 중인 이름이 있다 — 되맞춤이 돌면 빈 이룸이 값으로 덮인다.
      c.read(onboardingProvider.notifier).setNickname('하늘이');
      final fetchedBefore = memberFetches;

      final result = await c.read(profileSessionProvider.notifier).ensureProfile();

      expect(result.isOk, isTrue);
      expect(result.value, isTrue);
      expect(repo.creates, 1);
      expect(c.read(profileSessionProvider).selectedId, 'p-new');
      expect(c.read(profileSessionProvider).noProfile, isFalse);
      expect(storage.selectedProfileId, 'p-new');
      // 회원 정보를 다시 받으면 빈 이룸이로 입력을 덮는다 — 저장을 마친 뒤 화면이 받는다.
      await Future<void>.delayed(Duration.zero);
      expect(memberFetches, fetchedBefore);
      expect(c.read(onboardingProvider).childNickname, '하늘이');
    });

    test('이룸이가 없음 상태(noProfile)에서 만들면 풀린다', () async {
      final c = build();
      await settle(c);
      c.read(profileSessionProvider.notifier).markNoProfile();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(profileSessionProvider).noProfile, isTrue);

      await c.read(profileSessionProvider.notifier).ensureProfile();

      expect(c.read(profileSessionProvider).noProfile, isFalse);
    });

    test('이미 이룸이가 있으면 부르지 않는다', () async {
      shown = memberWith([kProfileA]);
      final c = build();
      await settle(c);

      final result = await c.read(profileSessionProvider.notifier).ensureProfile();

      expect(result.value, isFalse);
      expect(repo.creates, 0);
    });

    test('옛 서버(목록 필드 없음)는 없음으로 읽지 않는다 — 부르지 않는다 (#362 규칙)', () async {
      shown = Member.fromJson({'nickname': '하늘이'});
      repo.me = shown;
      final c = build();
      await settle(c);

      final result = await c.read(profileSessionProvider.notifier).ensureProfile();

      expect(result.isOk, isTrue);
      expect(repo.creates, 0);
    });

    test('회원 정보를 받지 못했으면 한 번 더 받아 보고, 그래도 모르면 부르지 않는다', () async {
      final c = ProviderContainer(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          memberRepositoryProvider.overrideWithValue(repo),
          memberProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(c.dispose);
      await c.read(memberProvider.future);

      final result = await c.read(profileSessionProvider.notifier).ensureProfile();

      expect(result.isOk, isTrue);
      expect(repo.creates, 0);
    });

    test('받아 둔 정보가 없을 때 직접 받아 보니 이룸이가 없다고 하면 만든다', () async {
      repo.me = const Member(profiles: [], profilesKnown: true);
      final c = ProviderContainer(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          memberRepositoryProvider.overrideWithValue(repo),
          memberProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(c.dispose);
      await c.read(memberProvider.future);

      final result = await c.read(profileSessionProvider.notifier).ensureProfile();

      expect(result.value, isTrue);
      expect(repo.creates, 1);
    });

    test('이룸이 휴대폰에서는 부르지 않는다', () async {
      await storage.setElumiDevice(true);
      final c = build();
      await settle(c);

      final result = await c.read(profileSessionProvider.notifier).ensureProfile();

      expect(result.value, isFalse);
      expect(repo.creates, 0);
    });

    test('실패하면 실패를 돌려주고 상태를 건드리지 않는다', () async {
      repo.createResult = Attempt.failed(
        serverFailure(500, ServerErrorCode.unknown),
      );
      final c = build();
      await settle(c);
      final before = c.read(profileSessionProvider);

      final result = await c.read(profileSessionProvider.notifier).ensureProfile();

      expect(result.isOk, isFalse);
      expect(c.read(profileSessionProvider), before);
      expect(storage.selectedProfileId, isNull);
    });

    test('실패한 뒤 다시 부르면 다시 시도한다', () async {
      repo.createResult = Attempt.failed(
        const AppFailure(fault: NetworkFault.offline),
      );
      final c = build();
      await settle(c);
      final notifier = c.read(profileSessionProvider.notifier);
      expect((await notifier.ensureProfile()).isOk, isFalse);

      repo.createResult = Attempt.ok(memberWith([created]));
      final retry = await notifier.ensureProfile();

      expect(retry.value, isTrue);
      expect(repo.creates, 2);
    });

    test('옛 서버(404·405)는 기존 동작 그대로 이어 간다', () async {
      repo.createResult = Attempt.failed(
        serverFailure(404, ServerErrorCode.unknown),
      );
      final c = build();
      await settle(c);

      final result = await c.read(profileSessionProvider.notifier).ensureProfile();

      expect(result.isOk, isTrue);
      expect(result.value, isFalse);
      expect(c.read(profileSessionProvider).selectedId, isNull);
    });

    test('두 번 눌러도 요청은 하나다', () async {
      final c = build();
      await settle(c);
      final notifier = c.read(profileSessionProvider.notifier);

      final results = await Future.wait([
        notifier.ensureProfile(),
        notifier.ensureProfile(),
      ]);

      expect(repo.creates, 1);
      expect(results.every((r) => r.isOk), isTrue);
    });
  });
}

class _FakeMemberRepo extends MemberRepository {
  _FakeMemberRepo() : super(dio: Dio());

  int creates = 0;
  Attempt<Member> createResult = const Attempt.failed(
    AppFailure(fault: NetworkFault.app),
  );
  Member? me;

  @override
  Future<Member?> getMyInfo() async => me;

  @override
  Future<Attempt<Member>> createProfile() async {
    creates++;
    await Future<void>.delayed(Duration.zero);
    return createResult;
  }
}
