import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_summary_tile.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// 온보딩 예시 일과의 홈 타일 표시 (#803 → #823 에서 칩 제거)
void main() {
  Widget wrap(Routine routine) => ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (context, _) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: RoutineSummaryTile(routine: routine, progress: 0)),
    ),
  );

  testWidgets('온보딩 예시 일과도 보호자가 만든 일과처럼 칩 없이 제목만 보인다 (#823)', (tester) async {
    await tester.pumpWidget(
      wrap(const Routine(id: 'r1', title: '아침 준비', isExample: true)),
    );

    expect(find.text('아침 준비'), findsOneWidget);
    expect(find.text('예시'), findsNothing);
  });
}
