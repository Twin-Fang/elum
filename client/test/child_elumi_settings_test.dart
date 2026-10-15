import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_dialog.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/link/presentation/elumi_settings_screen.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/no_disk_cache.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/app/dio_provider.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/core/router/routes.dart';

/// 이룸이 휴대폰의 상단 바와 설정 페이지 (이슈 #363 · #198 19번 · #488).
///
/// 이룸이 휴대폰은 보호자 화면에 갈 곳이 없다. 톱니가 설정 **페이지**를 열고(보호자 설정과 같다 — 바텀시트가 아니다, #488), 페이지의 `로그아웃`·`회원탈퇴`는
/// **이 휴대폰의 연결만** 끊는다. 되돌릴 수 없는 동작이라 성공·실패·이미 끊김을 모두 밟는다 —
/// 서버가 끊기지 않았는데 로컬만 비우면 보호자 설정에는 계속 `연결됨`이 남는다.
void main() {
  useFigmaViewport();

  late FakeAdapter adapter;
  late Map<String, Object?> routes;
  late InMemoryStorage storage;
  late InMemoryTokenStore tokens;

  setUp(() async {
    routes = {'DELETE /api/device-links/current': const <String, Object?>{}};
    adapter = FakeAdapter(routes);
    storage = InMemoryStorage(elumiDevice: true, onboardingCompleted: true);
    await storage.setNickname('하늘이');
    await storage.setCharacter('FOX');
    await storage.setCachedTodayRoutinesJson('[{"id":"r1"}]');
    tokens = InMemoryTokenStore(accessToken: 'a', refreshToken: 'r');
  });

  Widget wrap({bool elumi = true}) {
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: Routes.child,
      routes: [
        GoRoute(
          path: Routes.child,
          builder: (context, state) => const ChildHomeScreen(),
        ),
        GoRoute(
          path: Routes.childSettings,
          builder: (context, state) => const ElumiSettingsScreen(),
        ),
        GoRoute(
          path: Routes.childStars,
          builder: (context, state) => const Scaffold(body: Text('별 화면')),
        ),
        GoRoute(
          path: Routes.modeSwitch,
          builder: (context, state) => const Scaffold(body: Text('비밀암호 화면')),
        ),
        GoRoute(
          path: Routes.roleSelect,
          builder: (context, state) => const Scaffold(body: Text('역할 선택')),
        ),
        GoRoute(
          path: Routes.linkEnter,
          builder: (context, state) => const Scaffold(body: Text('연결 암호 넣기')),
        ),
        // 스스로 로그아웃·탈퇴한 뒤의 도착지 (#542)
        GoRoute(
          path: Routes.login,
          builder: (context, state) => const Scaffold(body: Text('로그인')),
        ),
      ],
    );
    if (!elumi) storage = InMemoryStorage(onboardingCompleted: true);
    return ProviderScope(
      overrides: [
        dioProvider.overrideWithValue(dio),
        tokenStoreProvider.overrideWithValue(tokens),
        localStorageProvider.overrideWithValue(storage),
        noDiskCacheOverride(),
        // 실서버를 타지 않는다
        myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        memberProvider.overrideWith(
          (ref) async => const Member(totalStars: 12),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  Future<void> pump(WidgetTester tester, {bool elumi = true}) async {
    await tester.pumpWidget(wrap(elumi: elumi));
    await tester.pumpAndSettle();
  }

  Finder labeled(String label) => find.bySemanticsLabel(label);

  /// 설정 톱니를 눌러 설정 페이지로 간다 (#488 — 바텀시트가 아니라 페이지).
  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(labeled('설정 열기'));
    await tester.pumpAndSettle();
  }

  Finder dialogButton(String label) => find.descendant(
    of: find.byType(ElumDialogCard<bool>),
    matching: find.text(label),
  );


  group('설정 페이지', () {
    testWidgets('톱니를 누르면 바텀시트가 아니라 설정 페이지로 간다 (#488)', (tester) async {
      await pump(tester);
      await openSettings(tester);

      expect(find.byType(ElumiSettingsScreen), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing, reason: '보호자 설정과 같은 페이지다');
      // 홈은 뒤로 밀려 보이지 않는다
      expect(find.byType(ChildHomeScreen), findsNothing);
    });

  });

  group('로그아웃 · 회원탈퇴 — 이 휴대폰의 연결만 끊는다', () {

    testWidgets('로그아웃 확인: 서버가 끊긴 뒤 로컬을 전부 비우고 로그인 화면으로 간다 (#542)', (tester) async {
      await pump(tester);
      await openSettings(tester);

      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(adapter.calls, ['DELETE /api/device-links/current']);
      expect(find.text('로그인'), findsOneWidget);
      expect(find.text('연결 암호 넣기'), findsNothing, reason: '연결 화면에 갇혔었다 (#542)');
      expect(tokens.hasSession, isFalse);
      expect(storage.nickname, isNull);
      expect(storage.cachedTodayRoutinesJson, isNull);
      expect(
        storage.isElumiDevice,
        isFalse,
        reason: '스스로 나갔다 — 표식이 남으면 다시 켤 때 연결 화면에 갇힌다 (#542)',
      );
      expect(
        storage.isElumiLinkLost,
        isFalse,
        reason: '스스로 끊은 것이라 `끊어졌어요`를 말하지 않는다',
      );
    });

    testWidgets('회원탈퇴: 일과와 별이 보호자 휴대폰에 남는다고 말하고, 같은 연결 끊기를 한다', (tester) async {
      await pump(tester);
      await openSettings(tester);

      await tester.tap(find.text('회원탈퇴'));
      await tester.pumpAndSettle();
      expect(find.text('회원탈퇴 하실건가요?'), findsOneWidget);
      expect(find.textContaining('일과와 별은 보호자 휴대폰에'), findsOneWidget);
      expect(find.textContaining('이 휴대폰의 연결만 끊어져요'), findsOneWidget);
      // 로그아웃 확인창처럼 다시 쓰는 방법을 알려 준다
      expect(find.textContaining('연결 암호를 받아야 해요'), findsOneWidget);

      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(adapter.calls, ['DELETE /api/device-links/current']);
      expect(find.text('로그인'), findsOneWidget);
    });

    testWidgets('이미 끊겨 있으면(404) 실패로 보이지 않고 정리한 뒤 로그인 화면으로 간다', (tester) async {
      routes['DELETE /api/device-links/current'] = const FakeHttpError(
        404,
        errorCode: 'DEVICE_LINK_NOT_CONNECTED',
      );
      await pump(tester);
      await openSettings(tester);
      await tester.tap(find.text('로그아웃'));
      await tester.pumpAndSettle();
      await tester.tap(dialogButton('확인'));
      await tester.pumpAndSettle();

      expect(find.text('로그인'), findsOneWidget);
      expect(tokens.hasSession, isFalse);
    });

    for (final (name, response, expected) in [
      ('서버 오류(500)', const FakeHttpError(500), 'E-LINK-OUT/500'),
      (
        '서버가 이유를 준 403',
        const FakeHttpError(
          403,
          errorCode: 'DEVICE_LINK_ONLY_FOR_ELUMI',
          errorMessage: '이룸이 휴대폰에서만 할 수 있어요.',
        ),
        'DEVICE_LINK_ONLY_FOR_ELUMI',
      ),
      ('인터넷 없음', const FakeOffline(), 'E-NET-OFFLINE'),
    ]) {
      testWidgets('$name: 머물고 에러 코드를 보여주며 아무것도 지우지 않는다', (tester) async {
        routes['DELETE /api/device-links/current'] = response;
        await pump(tester);
        await openSettings(tester);
        await tester.tap(find.text('회원탈퇴'));
        await tester.pumpAndSettle();
        await tester.tap(dialogButton('확인'));
        await tester.pumpAndSettle();

        expect(find.textContaining('탈퇴하지 못했어요'), findsOneWidget);
        expect(find.textContaining(expected), findsOneWidget);

        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();

        // 서버에는 연결이 살아 있다 — 화면을 옮기면 보호자 설정과 어긋난다
        expect(find.text('로그인'), findsNothing);
        expect(find.text('로그아웃'), findsOneWidget, reason: '설정 페이지에 머문다');
        expect(tokens.hasSession, isTrue);
        expect(storage.nickname, '하늘이');
        expect(storage.cachedTodayRoutinesJson, isNotNull);
      });
    }

  });
}
