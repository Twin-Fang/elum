import 'package:dio/dio.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/link/application/link_reset.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/link/presentation/link_enter_screen.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';

/// 이룸이 휴대폰의 연결이 **밖에서 끊겼을 때** (이슈 #363 · #359).
///
/// 보호자가 연결을 끊으면 서버가 이 휴대폰의 리프레시 토큰을 폐기하고, 다음 요청의 토큰 갱신이 실패해
/// 세션이 끝난다. 이 휴대폰은 스스로 연결 해제 상태가 되어야 한다 — 이전 이룸이의 정보를 들고 있지 않고,
/// 연결 화면에서 `연결이 끊어졌어요`를 말한다.
void main() {
  useFigmaViewport();

  late InMemoryStorage storage;
  late InMemoryTokenStore tokens;
  late DeviceLinkRepository repo;

  setUp(() async {
    storage = InMemoryStorage(elumiDevice: true, onboardingCompleted: true);
    await storage.setNickname('하늘이');
    await storage.setCharacter('FOX');
    await storage.setCachedTodayRoutinesJson('[{"id":"r1"}]');
    await storage.setRoutineProgressJson('r1', '{"done":true}');
    tokens = InMemoryTokenStore(accessToken: 'a', refreshToken: 'r');
    repo = DeviceLinkRepository(dio: Dio(), tokens: tokens, storage: storage);
  });

  group('세션이 끝났을 때 이룸이 휴대폰이 하는 일', () {
    Future<({GoRouter router, ProviderContainer container})> pumpApp(
      WidgetTester tester,
    ) async {
      final router = GoRouter(
        initialLocation: Routes.child,
        routes: [
          GoRoute(
            path: Routes.child,
            builder: (context, state) => const Scaffold(body: Text('이룸이 홈')),
          ),
          GoRoute(
            path: Routes.roleSelect,
            builder: (context, state) => const Scaffold(body: Text('역할 선택')),
          ),
          // 세션이 끝난 뒤 연결 화면의 뒤로가기 도착지 (#542)
          GoRoute(
            path: Routes.login,
            builder: (context, state) => const Scaffold(body: Text('로그인')),
          ),
          GoRoute(
            path: Routes.linkEnter,
            builder: (context, state) => const LinkEnterScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageProvider.overrideWithValue(storage),
            deviceLinkRepositoryProvider.overrideWithValue(repo),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, child) =>
                MaterialApp.router(theme: AppTheme.light, routerConfig: router),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return (
        router: router,
        container: ProviderScope.containerOf(
          tester.element(find.text('이룸이 홈')),
        ),
      );
    }

    testWidgets('로컬을 비우고 연결 화면에서 `연결이 끊어졌어요`를 말한다', (tester) async {
      final app = await pumpApp(tester);

      await endElumiLinkAfterSessionLoss(
        repo: repo,
        router: app.router,
        container: app.container,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('보호자에게서 받은 코드를'), findsOneWidget);
      expect(find.textContaining('연결이 끊어졌어요'), findsOneWidget);
      expect(find.textContaining('보호자에게 새 연결 암호를 받아 입력해주세요'), findsOneWidget);
      expect(storage.nickname, isNull);
      expect(storage.character, isNull);
      expect(storage.cachedTodayRoutinesJson, isNull);
      expect(storage.getRoutineProgressJson('r1'), isNull);
      expect(
        storage.isElumiDevice,
        isTrue,
        reason: '로그인 화면이 아니라 연결 화면으로 가야 한다 (#206)',
      );
      expect(storage.isElumiLinkLost, isTrue);
    });

    testWidgets('연결 화면에서 뒤로 갈 수 있다 — 스택이 비지 않는다', (tester) async {
      final app = await pumpApp(tester);

      await endElumiLinkAfterSessionLoss(
        repo: repo,
        router: app.router,
        container: app.container,
      );
      await tester.pumpAndSettle();

      expect(app.router.canPop(), isTrue);
    });

    testWidgets('메모리에 남은 이전 이룸이 이름도 비운다', (tester) async {
      final app = await pumpApp(tester);
      expect(app.container.read(onboardingProvider).childNickname, '하늘이');

      await endElumiLinkAfterSessionLoss(
        repo: repo,
        router: app.router,
        container: app.container,
      );

      expect(
        app.container.read(onboardingProvider).childNickname,
        isNot('하늘이'),
      );
    });
  });

  group('연결 화면의 안내', () {
    Widget wrapEnter() {
      final router = GoRouter(
        initialLocation: Routes.linkEnter,
        routes: [
          GoRoute(
            path: Routes.linkEnter,
            builder: (context, state) => const LinkEnterScreen(),
          ),
        ],
      );
      return ProviderScope(
        overrides: [deviceLinkRepositoryProvider.overrideWithValue(repo)],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, child) =>
              MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      );
    }

    testWidgets('끊긴 적이 없으면 말하지 않는다 — 처음 연결하는 사람에게 겁주지 않는다', (tester) async {
      await tester.pumpWidget(wrapEnter());
      await tester.pumpAndSettle();

      expect(find.textContaining('연결이 끊어졌어요'), findsNothing);
    });

    testWidgets('앱을 껐다 켜도 표식이 남아 있으면 말한다', (tester) async {
      await storage.setElumiLinkLost(true);
      await tester.pumpWidget(wrapEnter());
      await tester.pumpAndSettle();

      expect(find.textContaining('연결이 끊어졌어요'), findsOneWidget);
    });

    testWidgets('틀린 암호를 넣으면 그 안내가 먼저다', (tester) async {
      await storage.setElumiLinkLost(true);
      await tester.pumpWidget(wrapEnter());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'A0K3M9');
      await tester.pumpAndSettle();
      // 시작하기를 눌러야 보낸다 (시안 1274:7988, #493)
      await tester.tap(find.text('시작하기'));
      await tester.pumpAndSettle();

      expect(find.text('암호가 맞지 않아요'), findsOneWidget);
      expect(find.textContaining('연결이 끊어졌어요'), findsNothing);
    });
  });
}
