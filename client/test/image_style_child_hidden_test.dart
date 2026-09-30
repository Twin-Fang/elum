import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

/// 그림 방식은 **보호자만** 바꾼다 (#458 E12).
///
/// 이룸이가 카드 그림 방식을 바꿀 이유가 없다. 이룸이 화면에는 그 길이 없어야 하고,
/// 보호자 설정은 모드 전환 PIN 을 거쳐야 열린다.
void main() {
  useFigmaViewport();

  testWidgets('E12 이룸이 홈에는 그림 방식으로 가는 길이 없다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          myRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          todayRoutinesProvider.overrideWith((ref) async => const <Routine>[]),
          memberProvider.overrideWith((ref) async => const Member(nickname: '하늘이')),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: GoRouter(
              initialLocation: Routes.child,
              routes: [
                GoRoute(
                  path: Routes.child,
                  builder: (context, state) => const ChildHomeScreen(),
                ),
                // 이 경로가 열리면 이룸이 화면에서 새어 나간 것이다
                GoRoute(
                  path: Routes.guardianImageStyle,
                  builder: (context, state) =>
                      const Scaffold(body: Text('새어 나감')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('그림 방식'), findsNothing);
    expect(find.text('실사'), findsNothing);
    expect(find.text('새어 나감'), findsNothing);
  });
}
