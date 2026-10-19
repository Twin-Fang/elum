import 'package:elum/features/child/presentation/child_home_screen.dart';
import 'package:elum/features/child/presentation/child_routine_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/adaptive_test_app.dart';
import 'helpers/child_demo_overrides.dart';

/// 이룸이 홈: 폰은 지금 그대로, 세로 태블릿은 가운데 열, 가로 태블릿은 왼쪽 인사말 + 오른쪽 일과 목록
/// 깨지면: 이룸이가 쓰는 태블릿 홈이 폰 모양으로 늘어나거나 일과 타일이 화면 끝까지 퍼진다.
void main() {
  Future<void> pumpHome(WidgetTester tester, Size size) async {
    setTestWindowSize(tester, size);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...childDemoOverrides()],
        child: adaptiveTestApp(home: const ChildHomeScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  final greeting = find.textContaining('하늘이가');
  final firstTile = find.byType(ChildRoutineTile).first;

  testWidgets('폰 393x852: 인사말 아래에 타일, 타일은 거의 전폭 (회귀 0)', (tester) async {
    await pumpHome(tester, const Size(393, 852));

    expect(tester.getCenter(greeting).dy, lessThan(tester.getCenter(firstTile).dy));
    expect(tester.getSize(firstTile).width, greaterThan(393 - 40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('세로 태블릿 820x1180: 타일이 폭 상한 안 가운데 열', (tester) async {
    await pumpHome(tester, const Size(820, 1180));

    final tileSize = tester.getSize(firstTile);
    expect(tileSize.width, lessThanOrEqualTo(560 * 1.3 + 1));
    expect(tester.getCenter(firstTile).dx, closeTo(820 / 2, 1));
    expect(tester.getCenter(greeting).dy, lessThan(tester.getCenter(firstTile).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('가로 태블릿 1194x834: 인사말은 왼쪽, 일과 목록은 오른쪽', (tester) async {
    await pumpHome(tester, const Size(1194, 834));

    expect(
      tester.getCenter(greeting).dx,
      lessThan(tester.getCenter(firstTile).dx),
      reason: '왼쪽 인사말, 오른쪽 목록',
    );
    expect(tester.getCenter(firstTile).dx, greaterThan(1194 / 2));
    expect(tester.getSize(firstTile).width, lessThan(1194 * 0.55));
    expect(tester.takeException(), isNull);
  });

  testWidgets('가로 + 낮은 창(1024x320)은 한 열 스크롤로 접는다', (tester) async {
    await pumpHome(tester, const Size(1024, 320));

    expect(tester.getCenter(greeting).dy, lessThan(tester.getCenter(firstTile).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('일과 타일을 누르면 상세로 간다 (태블릿 가로에서도 눌린다)', (tester) async {
    await pumpHome(tester, const Size(1194, 834));

    expect(tester.getRect(firstTile).overlaps(const Rect.fromLTWH(0, 0, 1194, 834)), isTrue);
    expect(
      tester.getSize(firstTile).height,
      greaterThanOrEqualTo(64),
      reason: '이룸이 터치 영역 64 이상',
    );
  });
}
