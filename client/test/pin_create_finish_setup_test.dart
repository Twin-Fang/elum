import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/guardian/presentation/pin_change_screen.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/pin_setup_auth.dart';

/// 첫 로그인 뒤 암호 만들기: 저장하면 실제 경로 가드를 거쳐도 보호자 홈에 도착해야 한다.
/// 가짜 인증만 쓰면 `guardianPinSetupPending` 이 저장 뒤에도 켜져 있는 결함이 가려진다.
void main() {
  useFigmaViewport();

  Widget wrap(PinSetupAuth auth) {
    final storage = InMemoryStorage(onboardingCompleted: true);
    final router = GoRouter(
      initialLocation: '${Routes.guardianPinChange}?from=login',
      // 앱의 실제 가드를 그대로 쓴다
      redirect: (context, state) => resolveRedirect(
        state.uri.path,
        hasSession: true,
        onboardingCompleted: true,
        skipOnboarding: false,
        requiresGuardianPinSetup: auth.guardianPinSetupPending,
      ),
      routes: [
        GoRoute(path: Routes.login, builder: (_, _) => const Scaffold(body: Text('로그인'))),
        GoRoute(path: Routes.guardian, builder: (_, _) => const Scaffold(body: Text('보호자 홈'))),
        GoRoute(
          path: Routes.guardianPinChange,
          builder: (_, state) => PinChangeScreen(createOnly: state.uri.queryParameters['from'] == 'login'),
        ),
      ],
    );
    return ProviderScope(
      overrides: [localStorageProvider.overrideWithValue(storage), authRepositoryProvider.overrideWithValue(auth)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  testWidgets('암호를 만들어 저장하면 보호자 홈으로 넘어간다', (tester) async {
    final auth = PinSetupAuth(allowed: true)..guardianPinSetupPending = true;
    await tester.pumpWidget(wrap(auth));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElumButton));
    await tester.pumpAndSettle();

    expect(find.text('보호자 홈'), findsOneWidget);
    expect(auth.guardianPinSetupPending, isFalse);
  });
}
