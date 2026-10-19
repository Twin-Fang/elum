import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/features/guardian/presentation/guardian_home_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/create_routine_button.dart';
import 'package:elum/features/guardian/presentation/widgets/today_routine_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/adaptive_test_app.dart';
import 'helpers/child_demo_overrides.dart';
import 'helpers/stub_routine_repository.dart';

/// 보호자 홈: 폰은 지금 그대로, 세로 태블릿은 가운데 열, 가로 태블릿은 왼쪽 머리말·만들기 + 오른쪽 일과 목록
/// 깨지면: 보호자가 태블릿(심사 기기 포함)에서 폰 폭 좁은 열만 보거나 일과 목록이 화면 끝까지 퍼진다.
void main() {
  Future<void> pumpHome(WidgetTester tester, Size size) async {
    setTestWindowSize(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...childDemoOverrides(isElumiDevice: false),
          routineRepositoryProvider.overrideWithValue(StubRoutineRepository()),
        ],
        child: adaptiveTestApp(home: const GuardianHomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  final createButton = find.byType(CreateRoutineButton);
  final todaySection = find.byType(TodayRoutineSection);

  testWidgets('폰 393x852: 만들기 버튼이 일과 목록 위, 거의 전폭 (회귀 0)', (tester) async {
    await pumpHome(tester, const Size(393, 852));

    expect(tester.getCenter(createButton).dy, lessThan(tester.getCenter(todaySection).dy));
    expect(tester.getSize(createButton).width, greaterThan(393 - 40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('세로 태블릿 820x1180: 가운데 열 안에 세로로 쌓인다', (tester) async {
    await pumpHome(tester, const Size(820, 1180));

    expect(tester.getSize(createButton).width, lessThanOrEqualTo(560 * 1.3 + 1));
    expect(tester.getCenter(createButton).dx, closeTo(820 / 2, 1));
    expect(tester.getCenter(createButton).dy, lessThan(tester.getCenter(todaySection).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('가로 태블릿 1194x834: 만들기는 왼쪽, 일과 목록은 오른쪽', (tester) async {
    await pumpHome(tester, const Size(1194, 834));

    expect(
      tester.getCenter(createButton).dx,
      lessThan(tester.getCenter(todaySection).dx),
      reason: '왼쪽 머리말·만들기, 오른쪽 일과 목록',
    );
    expect(tester.getSize(todaySection).width, greaterThan(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('가로 + 낮은 창(1024x320)은 한 열로 접힌다', (tester) async {
    await pumpHome(tester, const Size(1024, 320));

    expect(tester.getCenter(createButton).dy, lessThan(tester.getCenter(todaySection).dy));
    expect(tester.takeException(), isNull);
  });
}
