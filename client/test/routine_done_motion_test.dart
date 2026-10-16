import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/child/presentation/routine_done_screen.dart';
import 'package:elum/features/child/presentation/widgets/routine_done_lumi_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

/// 일과완료 화면 움직임: 동작 줄이기·끔이면 루미가 제자리, 켜면 시간이 지나 자리가 바뀐다.
void main() {
  // 없으면 800×600 으로 찍혀 시안 좌표 화면이 넘친다.
  useFigmaViewport();

  Widget wrap({
    required bool isMotionEnabled,
    bool isSystemReduceMotion = false,
  }) {
    return ProviderScope(
      overrides: [testStorageOverride(onboardingCompleted: true)],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: isSystemReduceMotion),
            child: child!,
          ),
          home: RoutineDoneScreen(isMotionEnabled: isMotionEnabled),
        ),
      ),
    );
  }

  Offset lumiPosition(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(RoutineDoneLumiMotion.lumiKey));

  /// 등장(0.7초)이 끝난 뒤 두 시점의 루미 자리를 잰다.
  Future<(Offset, Offset)> measureAfterEntrance(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    final first = lumiPosition(tester);
    // 숨쉬기 한 주기(2초)의 4분의 1 지점
    await tester.pump(const Duration(milliseconds: 500));
    return (first, lumiPosition(tester));
  }

  testWidgets('움직임을 끄면 시간이 지나도 루미가 제자리다', (tester) async {
    await tester.pumpWidget(wrap(isMotionEnabled: false));
    await tester.pump();

    final (first, second) = await measureAfterEntrance(tester);

    expect(second, first);
  });

  testWidgets('시스템 동작 줄이기가 켜져 있으면 움직임을 켜도 제자리다', (tester) async {
    await tester.pumpWidget(
      wrap(isMotionEnabled: true, isSystemReduceMotion: true),
    );
    await tester.pump();

    final (first, second) = await measureAfterEntrance(tester);

    expect(second, first);
  });

  testWidgets('움직임을 켜면 숨쉬기로 루미 자리가 바뀐다', (tester) async {
    await tester.pumpWidget(wrap(isMotionEnabled: true));
    await tester.pump();

    final (first, second) = await measureAfterEntrance(tester);

    expect(second.dy, isNot(first.dy));
  });
}
