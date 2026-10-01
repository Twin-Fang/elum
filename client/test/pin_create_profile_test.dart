import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/onboarding/presentation/pin_screen.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/profile_fixtures.dart';
import 'helpers/test_storage.dart';

/// 이룸이가 없는 보호자가 온보딩을 마칠 때 (#362) — 저장 전에 새 이룸이를 먼저 만든다.
/// 서버는 이룸이 없이 이름을 저장하면 404 PROFILE_NOT_FOUND 로 막는다.
void main() {
  useFigmaViewport();

  late _FakeRepo repo;

  Widget wrap({required Member shown}) {
    repo.me = shown;
    final router = GoRouter(
      initialLocation: Routes.onboardingPin,
      routes: [
        GoRoute(
          path: Routes.onboardingPin,
          builder: (context, state) => const PinScreen(),
        ),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const Scaffold(body: Text('완료 화면')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        testStorageOverride(),
        memberRepositoryProvider.overrideWithValue(repo),
        memberProvider.overrideWith((ref) async => shown),
        // 아무도 구독하지 않은 회원 정보는 받아 둔 값이 없다 — 직접 받는 길도 같은 값을 준다.
        todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        pastRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        routineSuggestionsProvider.overrideWith((ref) async => const []),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  Future<void> reachCta(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();
  }

  const noProfile = Member(profiles: [], profilesKnown: true);

  setUp(() => repo = _FakeRepo());


  testWidgets('이룸이가 없으면 이름 저장 전에 만든다', (tester) async {
    await tester.pumpWidget(wrap(shown: noProfile));
    await tester.pumpAndSettle();
    await reachCta(tester);

    await tester.tap(find.byType(ElumButton));
    await tester.pumpAndSettle();

    expect(repo.log, ['create', 'nickname']);
    expect(find.text('완료 화면'), findsOneWidget);
  });

  testWidgets('이미 이룸이가 있으면 부르지 않는다', (tester) async {
    await tester.pumpWidget(wrap(shown: memberWith([kProfileA])));
    await tester.pumpAndSettle();
    await reachCta(tester);

    await tester.tap(find.byType(ElumButton));
    await tester.pumpAndSettle();

    expect(repo.log, ['nickname']);
    expect(find.text('완료 화면'), findsOneWidget);
  });

  testWidgets('만들지 못하면 에러 코드와 함께 알리고 이 화면에 남는다 — 다시 누르면 다시 시도한다', (tester) async {
    repo.createResult = const Attempt.failed(
      AppFailure(fault: NetworkFault.offline),
    );
    await tester.pumpWidget(wrap(shown: noProfile));
    await tester.pumpAndSettle();
    await reachCta(tester);

    await tester.tap(find.byType(ElumButton));
    await tester.pumpAndSettle();

    expect(find.textContaining('이룸이를 만들지 못했어요'), findsOneWidget);
    expect(find.textContaining('E-NET-OFFLINE'), findsOneWidget);
    // 이룸이 없이 이름을 저장하면 서버가 막는다 — 저장을 시도하지 않는다
    expect(repo.log, ['create']);
    expect(find.text('완료 화면'), findsNothing);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    repo.createResult = Attempt.ok(memberWith([kProfileA]));
    await tester.tap(find.byType(ElumButton));
    await tester.pumpAndSettle();

    expect(repo.log, ['create', 'create', 'nickname']);
    expect(find.text('완료 화면'), findsOneWidget);
  });

  testWidgets('연달아 두 번 눌러도 이룸이는 하나만 만든다', (tester) async {
    await tester.pumpWidget(wrap(shown: noProfile));
    await tester.pumpAndSettle();
    await reachCta(tester);

    await tester.tap(find.byType(ElumButton));
    await tester.tap(find.byType(ElumButton), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(repo.log.where((e) => e == 'create'), hasLength(1));
    expect(repo.log.where((e) => e == 'nickname'), hasLength(1));
  });
}

class _FakeRepo extends MemberRepository {
  _FakeRepo() : super(dio: Dio());

  final log = <String>[];
  Attempt<Member> createResult = Attempt.ok(memberWith([kProfileA]));
  Member? me;

  @override
  Future<Member?> getMyInfo() async => me;

  @override
  Future<Attempt<Member>> createProfile() async {
    log.add('create');
    return createResult;
  }

  @override
  Future<AppFailure?> updateNickname(String nickname) async {
    log.add('nickname');
    return null;
  }

  @override
  Future<AppFailure?> updateSupportGoals(List<String> goals) async => null;

  @override
  Future<AppFailure?> updateCharacter(String character) async => null;

  @override
  Future<AppFailure?> updateImageStyle(String imageStyle) async => null;
}
