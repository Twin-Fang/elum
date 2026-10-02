import 'package:dio/dio.dart';
import 'package:elum/core/network/dio_client.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/core/widgets/elum_scaffold.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/auth/domain/app_role.dart';
import 'package:elum/features/link/application/link_reset.dart';
import 'package:elum/features/link/data/device_link_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';

/// 이룸이 휴대폰에서 나가는 모든 길이 막다른 화면이 되지 않는다 (#542).
///
/// 로그아웃하면 연결 암호 화면에 갇혔다. 뒤로가기는 같은 화면만 다시 보여 주고 앱을 다시 켜도 그 화면이었다.
/// 기존 테스트가 못 잡은 이유는 **가드(redirect)가 없는 가짜 라우터**로 확인했기 때문이다 — 깔아 둔 역할
/// 선택이 가드에 걸려 연결 화면으로 바뀌는 일이 가짜 라우터에서는 일어나지 않는다. 그래서 여기서는 실제 앱
/// 라우터([createRouter])를 저장소·토큰과 같은 값으로 묶어 띄운다.
void main() {
  useFigmaViewport();

  late InMemoryStorage storage;
  late InMemoryTokenStore tokens;
  late FakeAdapter adapter;

  setUp(() async {
    // 로그인 화면 장면이 무한 반복이라 동작 줄이기를 켜야 settle 된다
    TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);

    // 보호자 코드로 연결을 마친 이룸이 휴대폰
    storage = InMemoryStorage(elumiDevice: true, onboardingCompleted: true);
    await storage.setSelectedRole(AppRole.elumi.storageValue);
    await storage.setNickname('하늘이');
    await storage.setCharacter('FOX');
    tokens = InMemoryTokenStore(accessToken: 'a', refreshToken: 'r');
    adapter = FakeAdapter({
      'DELETE /api/device-links/current': const <String, Object?>{},
    });
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  /// 실제 앱 라우터. 가드가 보는 값을 앱(`ElumApp`)과 같은 곳에서 읽는다.
  Future<({GoRouter router, ProviderContainer container})> pumpApp(
    WidgetTester tester, {
    required String start,
  }) async {
    final router = createRouter(
      isOnboardingCompleted: () => storage.isOnboardingCompleted,
      hasToken: () => tokens.hasSession,
      isElumiDevice: () => storage.isElumiDevice,
      hasRole: () => storage.selectedRole != null,
    );
    addTearDown(router.dispose);
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(dio),
          tokenStoreProvider.overrideWithValue(tokens),
          localStorageProvider.overrideWithValue(storage),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, child) =>
              MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      ),
    );
    // 실제 라우터는 시작 화면에서 출발해 스스로 갈 곳으로 옮긴다. 그 이동이 끝난 뒤에 시작점을 정해야
    // 늦게 도착한 시작 화면의 이동이 시험 중의 이동을 덮지 않는다.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    if (start != Routes.splash) {
      router.go(start);
      await tester.pumpAndSettle();
    }
    return (
      router: router,
      container: ProviderScope.containerOf(
        tester.element(find.byType(Navigator).first),
      ),
    );
  }

  /// 맨 위 화면. `currentConfiguration.uri` 는 push 로 쌓은 화면을 반영하지 않아 쓰지 않는다.
  String where(GoRouter router) =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  Future<void> tapBack(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel(ElumScaffold.backLabel).last);
    await tester.pumpAndSettle();
  }

  Future<void> confirmExit(WidgetTester tester, String row) async {
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(ElumDialogCard<bool>),
        matching: find.text('확인'),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final row in ['로그아웃', '회원탈퇴']) {
    group('이룸이 설정의 $row', () {
      testWidgets('로그인 화면으로 간다 — 연결 화면에 가두지 않는다', (tester) async {
        final app = await pumpApp(tester, start: Routes.childSettings);

        await confirmExit(tester, row);

        expect(where(app.router), Routes.login);
        expect(find.textContaining('보호자에게서 받은 코드를'), findsNothing);
      });

      testWidgets('이룸이 표식·역할까지 지운다 — 다시 켜도 로그인 화면이다', (tester) async {
        await pumpApp(tester, start: Routes.childSettings);

        await confirmExit(tester, row);

        expect(tokens.hasSession, isFalse);
        expect(storage.isElumiDevice, isFalse, reason: '남으면 앱 시작이 연결 화면으로 간다');
        expect(storage.selectedRole, isNull, reason: '남으면 다시 로그인해도 연결 화면으로 끌려간다');
        expect(storage.nickname, isNull);
        expect(storage.isElumiLinkLost, isFalse, reason: '스스로 나간 사람에게 끊겼다고 말하지 않는다');
      });
    });
  }

  group('보호자가 연결을 끊어 세션이 끝났을 때', () {
    testWidgets('연결 화면에서 끊겼다고 말하고, 뒤로가기는 로그인 화면으로 간다', (tester) async {
      final app = await pumpApp(tester, start: Routes.childSettings);

      await endElumiLinkAfterSessionLoss(
        repo: app.container.read(deviceLinkRepositoryProvider),
        router: app.router,
        container: app.container,
      );
      await tester.pumpAndSettle();

      expect(where(app.router), Routes.linkEnter);
      expect(find.text('연결이 끊어졌어요'), findsOneWidget);

      await tapBack(tester);

      expect(where(app.router), Routes.login, reason: '같은 연결 화면이 다시 나오면 갇힌 것이다');
    });
  });

  group('앱을 다시 켰을 때 (세션이 끊긴 이룸이 휴대폰)', () {
    setUp(() async {
      await tokens.clear();
      await storage.setElumiLinkLost(true);
    });

    testWidgets('시작 화면이 연결 화면으로 보내고, 뒤로가기는 로그인 화면으로 간다', (tester) async {
      // 시작 화면이 연출 대기(1.7초) 뒤 스스로 옮긴다 — pumpApp 이 그만큼 기다린다
      final app = await pumpApp(tester, start: Routes.splash);

      expect(where(app.router), Routes.linkEnter);

      await tapBack(tester);

      expect(where(app.router), Routes.login);
    });
  });

  group('연결 화면 아래에 아무것도 없을 때', () {
    testWidgets('세션이 없으면 뒤로가기가 로그인 화면으로 간다', (tester) async {
      await tokens.clear();
      final app = await pumpApp(tester, start: Routes.linkEnter);
      expect(app.router.canPop(), isFalse, reason: '전제: 돌아갈 화면이 없다');

      await tapBack(tester);

      expect(where(app.router), Routes.login);
    });

    testWidgets('세션이 있으면(역할만 고르고 연결 전) 역할 선택으로 간다', (tester) async {
      await storage.setElumiDevice(false);
      final app = await pumpApp(tester, start: Routes.linkEnter);

      await tapBack(tester);

      expect(where(app.router), Routes.roleSelect);
    });
  });

  testWidgets('역할 선택에서 이룸이를 고른 사람은 뒤로가기로 역할 선택에 돌아온다 (#212 그대로)', (
    tester,
  ) async {
    await storage.setElumiDevice(false);
    final app = await pumpApp(tester, start: Routes.roleSelect);

    app.router.push(Routes.linkEnter);
    await tester.pumpAndSettle();
    await tapBack(tester);

    expect(where(app.router), Routes.roleSelect);
  });
}
