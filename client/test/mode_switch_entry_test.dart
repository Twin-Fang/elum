import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/widgets/app_pressable.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/application/routine_notifier.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// 모드 전환 **진입점** 검증 (이슈 #61).
///
/// **왜 별도 파일인가.** 기존 `child_mode_test.dart`의 PIN 테스트는
/// `ModeSwitchScreen`을 직접 띄워 검증한다. 그래서 "홈 화면의 버튼이 실제로
/// PIN 화면을 거치는가"는 아무도 확인하지 않았다 — 진입점이 PIN을 건너뛰도록
/// 바뀌어도 테스트는 전부 초록불이다.
///
/// 실제로 그 일이 일어났다. 보호자 홈의 캐릭터 배지가
/// `context.go(Routes.child)`로 바뀌어 **PIN 없이 아이 화면으로** 넘어갔는데
/// 322개 테스트가 모두 통과했다.
///
/// 이 파일은 화면이 아니라 **경로**를 고정한다.
void main() {
  useFigmaViewport();

  Widget wrap(Widget screen) {
    final router = GoRouter(
      initialLocation: Routes.guardian,
      routes: [
        GoRoute(path: Routes.guardian, builder: (context, state) => screen),
        GoRoute(
          path: Routes.child,
          builder: (context, state) => const Scaffold(body: Text('아이 홈')),
        ),
        GoRoute(
          path: Routes.modeSwitch,
          builder: (context, state) => const Scaffold(body: Text('PIN 화면')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        testStorageOverride(onboardingCompleted: true, pin: '1234'),
        myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
        memberProvider.overrideWith((ref) async => null),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('보호자 홈에서 아이 화면으로 갈 때 PIN 화면을 거친다', (tester) async {
    // 이슈 #61의 "예상 동작" — 양방향 모두 PIN을 요구한다.
    // 한쪽만 막으면 우회로가 생긴다.
    await tester.pumpWidget(wrap(const GuardianHomeScreen()));
    await tester.pumpAndSettle();

    // 우측 상단 캐릭터 배지가 아이 화면 입구다
    final badge = find.ancestor(
      of: svgWithAsset(AppAssets.homeCharacterBadge),
      matching: find.byType(AppPressable),
    );
    expect(badge, findsOneWidget, reason: '아이 화면 입구(캐릭터 배지)가 있어야 한다');

    await tester.tap(badge);
    await tester.pumpAndSettle();

    // PIN을 건너뛰고 바로 아이 화면에 도달하면 안 된다
    expect(
      find.text('아이 홈'),
      findsNothing,
      reason: '보호자 → 아이 전환은 PIN 화면을 거쳐야 한다 (이슈 #61)',
    );
  });
}
