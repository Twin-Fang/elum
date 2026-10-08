import 'package:dio/dio.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/storage/token_store.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/auth/data/oauth_sdk.dart';
import 'package:elum/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';

/// 약관은 마쳤지만 이룸이 정보가 없는 계정으로 로그인하면 **역할 선택부터** 묻는다 (#542).
///
/// 이룸이를 골라 연결했던 사람은 계정에 이룸이 정보가 없다(정보는 보호자 계정에 있다). 로그아웃한 뒤 다시
/// 로그인하면 이 결과(`onboarding`)가 나오는데, 예전에는 보호자 온보딩(이름 입력)으로 곧장 보내 이룸이를
/// 다시 고를 길이 없었다.
void main() {
  useFigmaViewport();

  setUp(() {
    // 로그인 장면이 무한 반복이라 동작 줄이기를 켜야 settle 된다
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

  testWidgets('이룸이 정보가 없는 계정은 이름 입력이 아니라 역할 선택으로 간다', (tester) async {
    final storage = InMemoryStorage();
    final router = GoRouter(
      initialLocation: Routes.login,
      routes: [
        GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
        GoRoute(
          path: Routes.roleSelect,
          builder: (_, _) => const Scaffold(body: Text('역할 선택')),
        ),
        GoRoute(
          path: Routes.onboardingName,
          builder: (_, _) => const Scaffold(body: Text('이름 입력')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
          authRepositoryProvider.overrideWithValue(_NeedsOnboarding(storage)),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, child) =>
              MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('카카오로 로그인'));
    await tester.pumpAndSettle();

    expect(find.text('역할 선택'), findsOneWidget);
    expect(find.text('이름 입력'), findsNothing);
  });
}

/// 로그인하면 `onboarding` 을 돌려주는 가짜 — 약관은 마쳤고 이룸이 정보가 없는 계정이다.
class _NeedsOnboarding extends AuthRepository {
  _NeedsOnboarding(InMemoryStorage storage)
    : super(
        dio: Dio(),
        storage: storage,
        tokens: InMemoryTokenStore(),
        sdk: OAuthSdk(),
      );

  @override
  Future<AuthResult> signInWith(OAuthProvider provider) async =>
      const AuthResult(AuthOutcome.onboarding);
}
