import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/presentation/widgets/aurora_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 움직이는 배경 테스트.
///
/// 배경이 "실제로 움직이는가"와 "꺼야 할 때 꺼지는가"를 함께 고정한다.
/// 둘 중 하나만 맞으면 의미가 없다. (docs/motion.md)
void main() {
  Widget wrap({bool reduceMotion = false}) {
    return MaterialApp(
      // 배경색을 AppColors 토큰에서 읽으므로 테마가 필요하다
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const Scaffold(body: AuroraBackground()),
      ),
    );
  }

  /// 첫 번째 원의 현재 정렬 위치를 읽는다
  Alignment firstAlignment(WidgetTester tester) {
    final align = tester.widgetList<Align>(
      find.descendant(
        of: find.byType(AuroraBackground),
        matching: find.byType(Align),
      ),
    ).first;
    return align.alignment as Alignment;
  }

  testWidgets('시간이 지나면 원이 움직인다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    final before = firstAlignment(tester);
    // 주기가 28초라 몇 초로는 눈에 띄게 움직인다
    await tester.pump(const Duration(seconds: 5));
    final after = firstAlignment(tester);

    expect(after, isNot(before));

    // 무한 반복이라 테스트를 끝내려면 멈춰야 한다
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('애니메이션 끄기를 켜면 움직이지 않는다', (tester) async {
    // 움직임이 어지럼증을 유발하는 사용자가 있다
    await tester.pumpWidget(wrap(reduceMotion: true));
    await tester.pump();

    final before = firstAlignment(tester);
    await tester.pump(const Duration(seconds: 5));

    expect(firstAlignment(tester), before);
    // 돌고 있으면 여기서 타임아웃난다
    await tester.pumpAndSettle();
  });

  testWidgets('세 광원이 흩어지지 않고 붙어 있다', (tester) async {
    // 디자이너 요청 — 구석구석 떠다니면 광원 셋이 따로 노는 것처럼 보인다.
    await tester.pumpWidget(wrap());
    await tester.pump();

    for (var elapsed = 0; elapsed < 40; elapsed += 4) {
      final positions = tester
          .widgetList<Align>(
            find.descendant(
              of: find.byType(AuroraBackground),
              matching: find.byType(Align),
            ),
          )
          .map((a) => a.alignment as Alignment)
          .toList();

      // 어느 두 광원도 화면 절반 이상 떨어지지 않는다
      for (final a in positions) {
        for (final b in positions) {
          expect((a.x - b.x).abs(), lessThan(1.0));
          expect((a.y - b.y).abs(), lessThan(1.0));
        }
      }
      await tester.pump(const Duration(seconds: 4));
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('원을 세 개 그린다', (tester) async {
    await tester.pumpWidget(wrap(reduceMotion: true));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(AuroraBackground),
        matching: find.byType(Align),
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('배경만 재페인트되도록 격리한다', (tester) async {
    await tester.pumpWidget(wrap(reduceMotion: true));
    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(AuroraBackground),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });

  testWidgets('화면을 벗어나면 컨트롤러를 정리한다', (tester) async {
    // 보이지 않아도 돌면 배터리를 먹는다
    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(seconds: 2));

    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(find.byType(AuroraBackground), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
