import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/presentation/widgets/routine_summary_tile.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// 홈 일과 타일의 `예시` 배지 (#803)
void main() {
  Widget wrap(Routine routine) => ScreenUtilInit(
    designSize: const Size(393, 852),
    builder: (context, _) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: RoutineSummaryTile(routine: routine, progress: 0)),
    ),
  );

  testWidgets('예시 일과에는 예시 표시가 붙는다 — 보호자가 직접 만든 것과 구분', (tester) async {
    await tester.pumpWidget(
      wrap(const Routine(id: 'r1', title: '아침 준비', isExample: true)),
    );

    expect(find.text('예시'), findsOneWidget);
  });

  testWidgets('일반 일과에는 예시 표시가 없다', (tester) async {
    await tester.pumpWidget(wrap(const Routine(id: 'r1', title: '아침 준비')));

    expect(find.text('예시'), findsNothing);
  });
}
