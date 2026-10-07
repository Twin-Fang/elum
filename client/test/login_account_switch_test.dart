import 'package:dio/dio.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/auth/data/oauth_sdk.dart';
import 'package:elum/features/auth/presentation/login_screen.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';

/// 다른 계정으로 로그인했을 때 이전 계정의 일과가 메모리에 남지 않는다 (#482).
///
/// 일과 목록 provider 는 계정과 무관해서 한 번 받으면 앱이 꺼질 때까지 값을 들고 있다.
/// 로그아웃·탈퇴 뒤 앱을 끄지 않고 다른 계정으로 들어오면 홈이 이전 계정의 목록을 그대로 그렸다.
void main() {
  useFigmaViewport();

  testWidgets('로그인하면 오늘·지난·전체 일과와 추천을 새 계정 기준으로 다시 받는다', (tester) async {
    final repo = _AccountRepo()..account = 'A';
    final storage = InMemoryStorage(onboardingCompleted: true, pin: '1234');
    final router = GoRouter(
      initialLocation: Routes.login,
      routes: [
        GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: Routes.guardian,
          builder: (_, _) => const Scaffold(body: Text('보호자 홈')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          routineRepositoryProvider.overrideWithValue(repo),
          authRepositoryProvider.overrideWithValue(_LoginSucceeds(storage)),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, child) =>
              MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LoginScreen)),
    );

    // 계정 A 로 홈을 쓰던 상태 — 네 목록이 메모리에 담긴다
    Future<List<String>> titles() async => [
      for (final p in [
        todayRoutinesProvider,
        pastRoutinesProvider,
        myRoutinesProvider,
      ])
        ...(await container.read(p.future)).map((r) => r.title),
      ...(await container.read(routineSuggestionsProvider.future)).map(
        (s) => s.text,
      ),
    ];
    expect(await titles(), everyElement(endsWith('A')));

    // 로그아웃·탈퇴 뒤 앱을 끄지 않고 계정 B 로 로그인한다
    repo.account = 'B';
    await tester.tap(find.text('카카오로 로그인'));
    await tester.pumpAndSettle();

    expect(find.text('보호자 홈'), findsOneWidget);
    final after = await titles();
    expect(after, hasLength(4));
    expect(after, everyElement(endsWith('B')), reason: '이전 계정(A) 목록이 남았다: $after');
  });
}

/// 어느 계정으로 부르느냐에 따라 제목이 달라지는 가짜 — 남아 있는 값이 어느 계정 것인지 가린다.
class _AccountRepo implements RoutineRepository {
  String account = 'A';

  Routine _routine(String kind) =>
      Routine(id: '$kind$account', title: '$kind$account');

  @override
  Future<List<Routine>> getTodayRoutines() async => [_routine('오늘')];

  @override
  Future<List<Routine>> getPastRoutines() async => [_routine('지난')];

  @override
  Future<List<Routine>> getMyRoutines() async => [_routine('전체')];

  @override
  Future<List<RoutineSuggestion>> getSuggestions() async => [
    RoutineSuggestion(icon: '💧', text: '추천$account'),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 로그인하면 성공하는 가짜.
class _LoginSucceeds extends AuthRepository {
  _LoginSucceeds(this._storage)
    : super(
        dio: Dio(),
        storage: _storage,
        tokens: InMemoryTokenStore(),
        sdk: OAuthSdk(),
      );

  final InMemoryStorage _storage;

  @override
  Future<AuthResult> signInWith(OAuthProvider provider) async {
    await _storage.clearSelectedProfileId();
    return const AuthResult(AuthOutcome.home);
  }
}
