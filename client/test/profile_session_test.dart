import 'package:elum/core/network/session_expiry.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/shared/models/character.dart';
import 'package:elum/features/onboarding/domain/image_style.dart';
import 'package:elum/shared/models/support_goal.dart';
import 'package:elum/features/profile/application/profile_session.dart';
import 'package:elum/features/profile/data/profile_repository.dart';
import 'package:elum/features/profile/domain/profile_summary.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/features/member/application/member_providers.dart';

/// 보호자가 이룸이를 고르는 상태 (#362 · E27·E29·E44).
///
/// 이 상태가 틀리면 **엉뚱한 이룸이의 일과를 만들거나 보여 준다.** 그래서 고른 값이 저장되는지,
/// 바꿀 때 이룸이마다 다른 값(이름·캐릭터·일과)이 함께 바뀌는지, 잃었을 때 되돌아오는지를
/// 고정한다.
void main() {
  const a = ProfileSummary(
    id: 'p-a',
    nickname: '하늘이',
    character: 'LULU',
    imageStyle: ImageStyle.cartoon,
  );
  const b = ProfileSummary(
    id: 'p-b',
    nickname: '바다',
    character: 'POPO',
    imageStyle: ImageStyle.realistic,
  );

  late InMemoryStorage storage;
  late Member member;
  var memberFetches = 0;
  var todayFetches = 0;

  ProviderContainer build() {
    final container = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        memberProvider.overrideWith((ref) async {
          memberFetches++;
          return member;
        }),
        todayRoutinesProvider.overrideWith((ref) async {
          todayFetches++;
          return const <Routine>[];
        }),
        pastRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        routineSuggestionsProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);
    // 화면이 보고 있는 것처럼 살려 둔다 — 안 보는 provider 는 무효화해도 다시 받지 않는다.
    container.listen(todayRoutinesProvider, (_, _) {});
    container.listen(profileSessionProvider, (_, _) {});
    return container;
  }

  /// 서버 응답이 들어와 목록이 맞춰질 때까지 기다린다.
  Future<void> settle(ProviderContainer c) async {
    await c.read(memberProvider.future);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() {
    storage = InMemoryStorage(onboardingCompleted: true, pin: '1234');
    member = const Member(nickname: '하늘이', profiles: [a, b]);
    memberFetches = 0;
    todayFetches = 0;
  });

  group('온보딩을 마치기 전', () {
    // 가입 직후 서버 프로필은 비어 있다. 그 빈 값이 입력 중인 이름·그림 방식을 지우면
    // "직접 찍은 사진"이 만화로 저장돼 AI 그림 비용이 나간다.
    test('서버의 빈 이룸이가 입력 중인 값을 지우지 않는다', () async {
      storage = InMemoryStorage(); // 온보딩 미완료
      member = const Member(
        profiles: [ProfileSummary(id: 'p-new', imageStyle: ImageStyle.cartoon)],
      );
      final c = build();
      c.read(onboardingProvider.notifier)
        ..setNickname('하늘이')
        ..setCharacter(CardCharacter.fox)
        ..setImageStyle(ImageStyle.photoOnly);
      await settle(c);

      final profile = c.read(onboardingProvider);
      expect(profile.childNickname, '하늘이');
      expect(profile.cardCharacter, CardCharacter.fox);
      expect(profile.imageStyle, ImageStyle.photoOnly);
      // 고른 이룸이는 맞춘다 — 이후 요청이 같은 이룸이를 가리켜야 한다.
      expect(c.read(profileSessionProvider).selectedId, 'p-new');
    });

    // 새 휴대폰에서 기존 계정으로 들어온 경우는 서버 값이 이긴다.
    test('이름이 있는 서버 이룸이는 그대로 덮는다', () async {
      storage = InMemoryStorage();
      member = const Member(profiles: [b]);
      final c = build();
      c.read(onboardingProvider.notifier).setNickname('옛 입력');
      await settle(c);

      expect(c.read(onboardingProvider).childNickname, '바다');
      expect(c.read(onboardingProvider).imageStyle, ImageStyle.realistic);
    });
  });

  group('서버 목록에 맞춰 고른다', () {
    test('고른 적이 없으면 첫 이룸이를 고르고 저장한다 — 서버가 헤더 없이 주는 것과 같다', () async {
      final c = build();
      await settle(c);

      expect(c.read(profileSessionProvider).selectedId, 'p-a');
      expect(storage.selectedProfileId, 'p-a');
    });

    test('저장해 둔 이룸이가 목록에 있으면 그대로 둔다 (앱을 다시 켜도)', () async {
      await storage.setSelectedProfileId('p-b');
      member = const Member(nickname: '바다', profiles: [a, b]);
      final c = build();
      await settle(c);

      expect(c.read(profileSessionProvider).selectedId, 'p-b');
    });

    test('이룸이마다 다른 로컬 값을 서버 값으로 덮는다 — 이름·캐릭터·그림 방식·도움 목표 (E44)', () async {
      await storage.setNickname('옛 이름');
      member = const Member(
        nickname: '바다',
        supportGoals: ['STEP_BY_STEP'],
        profiles: [a, b],
      );
      await storage.setSelectedProfileId('p-b');
      final c = build();
      await settle(c);

      final profile = c.read(onboardingProvider);
      expect(profile.childNickname, '바다');
      expect(profile.cardCharacter, CardCharacter.fox);
      expect(profile.imageStyle, ImageStyle.realistic);
      expect(profile.supportGoals, {SupportGoal.stepByStep});
      // 저장소에도 남는다 — 앱을 다시 켜면 여기서 읽는다
      expect(storage.nickname, '바다');
      expect(storage.character, 'POPO');
      expect(storage.imageStyle, 'REALISTIC');
      expect(storage.goals, ['STEP_BY_STEP']);
    });

    test('이룸이가 하나도 없으면 없음으로 표시하고 이룸이 값을 비운다 (E29)', () async {
      member = const Member(profiles: [], profilesKnown: true);
      await storage.setSelectedProfileId('p-gone');
      await storage.setNickname('하늘이');
      final c = build();
      await settle(c);
      await settle(c);

      expect(c.read(profileSessionProvider).noProfile, isTrue);
      expect(c.read(profileSessionProvider).selectedId, isNull);
      expect(storage.selectedProfileId, isNull);
      expect(storage.nickname, isNull);
      expect(storage.isOnboardingCompleted, isFalse);
      // 없음 처리가 회원 정보를 다시 받는데, 그 응답이 또 처리를 부르지 않는다
      expect(memberFetches, lessThan(4));
    });

    test('옛 서버(목록 필드 없음)는 이룸이 없음으로 읽지 않는다 — 온보딩 값을 지키고 선택하지 않는다 (E36)', () async {
      member = Member.fromJson({'nickname': '하늘이'});
      await storage.setNickname('하늘이');
      final c = build();
      await settle(c);

      expect(c.read(profileSessionProvider).noProfile, isFalse);
      expect(storage.isOnboardingCompleted, isTrue);
      expect(storage.nickname, '하늘이');
      expect(storage.selectedProfileId, isNull);
    });

    test('이룸이 휴대폰에서는 아무것도 하지 않는다 — 이룸이를 고르는 것은 보호자의 일이다', () async {
      await storage.setElumiDevice(true);
      final c = build();
      await settle(c);

      expect(c.read(profileSessionProvider).selectedId, isNull);
      expect(storage.selectedProfileId, isNull);
    });
  });

  group('이룸이를 바꾼다', () {
    test('저장하고 이름·캐릭터를 바꾸고 이룸이마다 다른 목록을 다시 받는다 (E44)', () async {
      final c = build();
      await settle(c);
      await storage.setCachedTodayRoutinesJson('[{"id":"r-a"}]');
      final todayBefore = todayFetches;
      final memberBefore = memberFetches;

      await c.read(profileSessionProvider.notifier).select(b);
      await settle(c);

      expect(c.read(profileSessionProvider).selectedId, 'p-b');
      expect(storage.selectedProfileId, 'p-b');
      expect(c.read(onboardingProvider).childNickname, '바다');
      expect(c.read(onboardingProvider).cardCharacter, CardCharacter.fox);
      // 오프라인 캐시에 바꾸기 전 이룸이의 일과가 남아 있으면 안 된다
      expect(storage.cachedTodayRoutinesJson, isNull);
      expect(todayFetches, greaterThan(todayBefore));
      expect(memberFetches, greaterThan(memberBefore));
    });

    test('만들던 일과 입력은 이룸이가 바뀌면 비운다 — 남의 이룸이에게 만들어 주지 않는다', () async {
      final c = build();
      await settle(c);
      c.read(routineFlowProvider.notifier).setRawInput('병원에 가요');

      await c.read(profileSessionProvider.notifier).select(b);

      expect(c.read(routineFlowProvider).rawInput, isEmpty);
    });

    test('같은 이룸이를 다시 고르면 아무것도 하지 않는다', () async {
      final c = build();
      await settle(c);
      final todayBefore = todayFetches;

      await c.read(profileSessionProvider.notifier).select(a);
      await settle(c);

      expect(todayFetches, todayBefore);
    });
  });

  group('고른 이룸이를 잃었다 (다른 휴대폰에서 나갔다)', () {
    test('선택을 풀고 목록을 다시 받아 첫 이룸이로 되돌아온다', () async {
      await storage.setSelectedProfileId('p-b');
      final c = build();
      await settle(c);
      member = const Member(nickname: '하늘이', profiles: [a]);

      c.read(profileSessionProvider.notifier).lost('p-b');
      await settle(c);
      await settle(c);

      expect(c.read(profileSessionProvider).selectedId, 'p-a');
      expect(storage.selectedProfileId, 'p-a');
    });

    test('이미 다른 이룸이로 바꾼 뒤에 늦게 온 알림은 무시한다', () async {
      final c = build();
      await settle(c);
      await c.read(profileSessionProvider.notifier).select(b);
      await settle(c);
      final todayBefore = todayFetches;

      c.read(profileSessionProvider.notifier).lost('p-a');
      await settle(c);

      expect(c.read(profileSessionProvider).selectedId, 'p-b');
      expect(todayFetches, todayBefore);
    });
  });

  group('나갔다', () {
    test('고른 이룸이에서 나가면 남은 이룸이로 옮긴다', () async {
      final c = build();
      await settle(c);

      final next = await c.read(profileSessionProvider.notifier).left('p-a');

      expect(next, LeftOutcome.switched);
      expect(c.read(profileSessionProvider).selectedId, 'p-b');
      expect(c.read(onboardingProvider).childNickname, '바다');
    });

    test('다른 이룸이에서 나가도 지금 보는 이룸이는 그대로다', () async {
      final c = build();
      await settle(c);

      final next = await c.read(profileSessionProvider.notifier).left('p-b');

      expect(next, LeftOutcome.stayed);
      expect(c.read(profileSessionProvider).selectedId, 'p-a');
    });

    test('마지막 이룸이에서 나가면 이룸이 없음이다 — 이룸이 값은 비우되 휴대폰의 비밀암호는 남긴다 (E29·E45)', () async {
      member = const Member(nickname: '하늘이', profiles: [a]);
      final c = build();
      await settle(c);
      await storage.setNickname('하늘이');
      await storage.setCharacter('LULU');
      // 나간 뒤 서버는 연결된 이룸이가 없다고 답한다
      member = const Member(profiles: [], profilesKnown: true);

      final next = await c.read(profileSessionProvider.notifier).left('p-a');
      await settle(c);

      expect(next, LeftOutcome.none);
      expect(c.read(profileSessionProvider).noProfile, isTrue);
      expect(c.read(profileSessionProvider).selectedId, isNull);
      expect(storage.selectedProfileId, isNull);
      expect(storage.nickname, isNull);
      expect(storage.isOnboardingCompleted, isFalse);
      expect(c.read(onboardingProvider).childNickname, isEmpty);
      // 비밀암호는 이룸이가 아니라 이 휴대폰의 것이다 (E45)
      expect(await storage.verifyPin('1234'), isTrue);
    });
  });

  group('나가기 — 남은 이룸이를 모를 때', () {
    test('회원 정보를 못 받은 채 나가도 이룸이 없음으로 읽지 않는다 — 온보딩 값을 지우지 않는다', () async {
      // 서버 응답이 한 번 실패해 목록을 모른다. 모르는 것을 "하나도 없다"로 읽으면 다른 이룸이가
      // 남아 있는데도 이룸이 값이 지워지고 온보딩으로 쫓겨난다.
      final c = ProviderContainer(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          memberProvider.overrideWith((ref) async => null),
          todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          pastRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          routineSuggestionsProvider.overrideWith((ref) async => const []),
        ],
      );
      addTearDown(c.dispose);
      await storage.setSelectedProfileId('p-a');
      await storage.setNickname('하늘이');
      c.listen(profileSessionProvider, (_, _) {});

      final outcome = await c.read(profileSessionProvider.notifier).left('p-a');

      expect(outcome, LeftOutcome.stayed);
      expect(c.read(profileSessionProvider).noProfile, isFalse);
      expect(storage.isOnboardingCompleted, isTrue);
      expect(storage.nickname, '하늘이');
      // 나간 이룸이는 더 고르지 않는다 — 다음에 받은 목록이 새로 정해 준다
      expect(storage.selectedProfileId, isNull);
    });
  });

  group('초대로 합류했다', () {
    test('합류한 이룸이를 고르고 온보딩을 마친 것으로 둔다 (E6)', () async {
      storage = InMemoryStorage(); // 새 가입자 — 온보딩 전
      member = const Member(profiles: [b]);
      final c = build();

      await c
          .read(profileSessionProvider.notifier)
          .joined(const ProfileJoin(profile: b, removedProfileIds: ['p-empty']));

      expect(c.read(profileSessionProvider).selectedId, 'p-b');
      expect(storage.selectedProfileId, 'p-b');
      expect(storage.isOnboardingCompleted, isTrue);
      expect(storage.selectedRole, 'guardian');
      expect(storage.nickname, '바다');
      expect(c.read(onboardingProvider).childNickname, '바다');
    });
  });

  group('세션이 끝났다', () {
    test('로그인이 풀리면 고른 이룸이를 잊는다 — 다른 계정이 들어와도 헤더에 남지 않게', () async {
      final c = build();
      await settle(c);
      expect(storage.selectedProfileId, 'p-a');

      c.read(sessionExpiryProvider.notifier).markExpired();
      await Future<void>.delayed(Duration.zero);

      expect(c.read(profileSessionProvider).selectedId, isNull);
      expect(storage.selectedProfileId, isNull);
    });
  });
}
