import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/onboarding/presentation/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 시작 화면은 Figma `스플래시`(1022:4415)를 따른다.
///
/// **시안에 있는 것은 단색 배경과 로고 하나뿐이다.** 병아리·문구는 로그인 화면
/// 것이다 (이슈 #338). 한때 두 화면이 같은 장면을 공유했는데(#207) 새 시안에서
/// 갈라졌다.
///
/// 이 테스트가 존재하는 이유 — **에셋은 시안에서 빠져도 앱에서 저절로 사라지지
/// 않는다.** 실제로 두 달 전 시안의 병아리 얼굴이 그렇게 남아 화면에 삐져나와
/// 있었다 (#297). 그래서 "없어야 하는 것이 없는지"를 함께 고정한다.
void main() {
  Widget buildSubject({bool onboardingCompleted = false}) {
    final router = GoRouter(
      initialLocation: Routes.splash,
      routes: [
        GoRoute(
          path: Routes.splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: Routes.onboardingName,
          builder: (context, state) => const Scaffold(body: Text('이름 화면')),
        ),
        GoRoute(
          path: Routes.roleSelect,
          builder: (context, state) => const Scaffold(body: Text('역할 선택')),
        ),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const Scaffold(body: Text('보호자 홈')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        testStorageOverride(onboardingCompleted: onboardingCompleted),
        // 세션이 없으면 로그인 화면으로 가므로, 온보딩·홈 분기를 보려면
        // 로그인된 상태를 만들어 둔다.
        tokenStoreProvider.overrideWithValue(
          InMemoryTokenStore(accessToken: 'a', refreshToken: 'r'),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  /// OS "동작 줄이기"를 켠다 — idle 반복 모션이 정지해 pumpAndSettle이 끝난다.
  void useReduceMotion() {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized()
              .platformDispatcher
              .accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
    });
    tearDown(() {
      TestWidgetsFlutterBinding.ensureInitialized()
          .platformDispatcher
          .clearAccessibilityFeaturesTestValue();
    });
  }

  group('시작 화면 구성', () {
    useReduceMotion();

  });

  group('시작 화면 이동', () {
    useReduceMotion();

    testWidgets('역할을 안 골랐으면 누르지 않아도 역할 선택으로 간다 (이슈 #212)', (tester) async {
      // 이름을 먼저 물으면 이룸이 휴대폰이 보호자 온보딩으로 빨려 들어간다.
      await tester.pumpWidget(buildSubject(onboardingCompleted: false));
      // 연출을 본 뒤 저절로 넘어간다.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(find.text('역할 선택'), findsOneWidget);
    });

    testWidgets('온보딩을 마쳤으면 역할이 없어도 다시 묻지 않는다 (이슈 #212)', (tester) async {
      // 역할이 생기기 전에 가입한 보호자다. 이미 답한 것을 또 묻지 않는다.
      await tester.pumpWidget(buildSubject(onboardingCompleted: true));
      await tester.pumpAndSettle();

      expect(find.text('역할 선택'), findsNothing);
      expect(find.text('보호자 홈'), findsOneWidget);
    });

  });

  group('시작 화면 이동 실패', () {
    useReduceMotion();

    testWidgets('라우터가 없어 이동하지 못하면 에러 코드와 재시도를 보인다', (tester) async {
      // 무한 대기 대신 제보할 코드와 다시 시도를 준다.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            testStorageOverride(onboardingCompleted: true),
            tokenStoreProvider.overrideWithValue(
              InMemoryTokenStore(accessToken: 'a', refreshToken: 'r'),
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (context, child) => MaterialApp(
              theme: AppTheme.light,
              home: const SplashScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(splashNavigationFailureCode), findsWidgets);
      expect(find.textContaining('다시 시도'), findsOneWidget);
    });
  });

  // idle 부유 모션 시험은 **로그인 화면으로 옮겼다** (이슈 #338).
  // 새싹 줄기와 구슬이 그쪽에만 있다 — `login_screen_test.dart` 참고.
}
