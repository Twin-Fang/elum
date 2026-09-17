import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// 로그인 화면 (이슈 #207 · 명세 §2-1).
///
/// 첫 화면에서 **바로** 로그인할 수 있어야 한다. 제목은 로고가 대신한다 —
/// 로고 바로 밑에서 같은 말을 한 번 더 하지 않는다.
void main() {
  useFigmaViewport();

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.login,
      routes: [
        GoRoute(
          path: Routes.login,
          builder: (context, state) => const LoginScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [testStorageOverride()],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('글자 제목 대신 로고를 쓴다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(svgWithAsset(AppAssets.logo), findsOneWidget);
    // 로고가 이미 이름을 말하고 있다. 밑에서 또 말하지 않는다.
    expect(find.textContaining('시작해볼까요'), findsNothing);
  });

  testWidgets('무엇을 하는 앱인지 한 줄로 말한다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('할 일을 카드로 만들어요'), findsOneWidget);
  });

  testWidgets('로그인 수단이 첫 화면에 모두 있다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // 한 번 더 눌러 들어가는 화면이 아니다.
    expect(find.text('카카오로 시작하기'), findsOneWidget);
    expect(find.text('네이버로 시작하기'), findsOneWidget);
    expect(find.text('Google로 시작하기'), findsOneWidget);
  });
}
