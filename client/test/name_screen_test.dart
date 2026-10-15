import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/onboarding/presentation/name_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 이름 화면은 Figma `온보딩_이름` 두 프레임을 따른다.
///
/// - 204:991  빈 상태 (placeholder · CTA disable)
/// - 204:1174 입력 완료 상태 (입력값 · CTA enable)
///
/// 두 프레임은 같은 화면의 상태 전이다. 별도 화면을 만들지 않고
/// 상태가 올바르게 갈리는지를 여기서 고정한다.
void main() {
  // 실기기와 같은 세로 여유에서 검증한다. 기본 800×600은 세로가 짧아
  // 키보드가 올라온 상황이 제대로 재현되지 않는다.
  useFigmaViewport();

  /// 로그인은 온보딩 앞으로 나갔다. 이 화면은 입력만 받는다.
  Widget buildSubject() {
    final router = GoRouter(
      initialLocation: Routes.onboardingName,
      routes: [
        GoRoute(
          path: Routes.onboardingName,
          builder: (context, state) => const NameScreen(),
        ),
        GoRoute(
          path: Routes.onboardingGoals,
          builder: (context, state) => const Scaffold(body: Text('목표 화면')),
        ),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const Scaffold(body: Text('보호자 홈')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        testStorageOverride(),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  /// CTA 활성 여부는 onPressed가 null인지로 판정한다.
  /// 색상값을 직접 비교하면 토큰이 바뀔 때마다 테스트가 깨진다.
  bool isNextButtonEnabled(WidgetTester tester) {
    final button = tester.widget<ElumButton>(find.byType(ElumButton));
    return button.onPressed != null;
  }


  group('입력 완료 상태 (204:1174)', () {
    testWidgets('공백만 입력하면 활성되지 않는다', (tester) async {
      // canProceedFromName이 trim()으로 판단한다
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      expect(isNextButtonEnabled(tester), isFalse);
    });

    testWidgets('입력 후 다음을 누르면 목표 화면으로 간다', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '하늘이');
      await tester.pumpAndSettle();

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      expect(find.text('목표 화면'), findsOneWidget);
    });



  });

  /// 실기기에서 키보드가 올라오자 화면이 노란 줄무늬로 깨졌다.
  /// 테스트는 키보드를 재현하지 않아 11개가 전부 통과했다.
  ///
  /// 오버플로 자체는 `flutter_test_config.dart`가 예외로 바꿔 잡는다.
  /// 여기서는 그 상황을 만들어 주는 것이 역할이다.
}
