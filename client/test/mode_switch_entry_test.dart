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
/// **PIN은 한 방향만 막는다.**
///
/// | 방향 | PIN |
/// |---|---|
/// | 보호자 → 아이 | ❌ 필요 없음 — 보호자는 이미 인증된 사용자다 |
/// | 아이 → 보호자 | ✅ 필요 — 아이가 보호자 화면에 들어가면 안 된다 |
///
/// 막아야 할 것은 **아이가 빠져나오는 것**이지 보호자가 들어가는 것이 아니다.
/// 보호자에게 매번 PIN을 묻는 것은 아이에게 화면을 넘겨줄 때마다 생기는
/// 불필요한 마찰이다.
///
/// **왜 별도 파일인가.** 기존 `child_mode_test.dart`의 PIN 테스트는
/// `ModeSwitchScreen`을 직접 띄워 검증한다. 그래서 "홈 화면의 버튼이 실제로
/// 어디로 가는가"는 아무도 확인하지 않았다 — 진입점 경로가 바뀌어도
/// 테스트는 전부 초록불이다. 이 파일은 화면이 아니라 **경로**를 고정한다.
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
        todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
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

  testWidgets('보호자 홈에서 아이 화면으로는 PIN 없이 바로 간다', (tester) async {
    // 보호자는 이미 인증된 사용자다. 아이에게 화면을 넘겨줄 때마다 PIN을
    // 묻는 것은 불필요한 마찰이다.
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

    expect(
      find.text('아이 홈'),
      findsOneWidget,
      reason: '보호자 → 아이 전환은 PIN 없이 바로 간다',
    );
    expect(find.text('PIN 화면'), findsNothing);
  });
}
