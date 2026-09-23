import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/presentation/widgets/aurora_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 움직이는 배경 테스트.
///
/// 배경이 "실제로 움직이는가"와 "꺼야 할 때 꺼지는가"를 함께 고정한다.
/// 둘 중 하나만 맞으면 의미가 없다. (docs/motion.md)
void main() {
  useFigmaViewport();

  Widget wrap({bool reduceMotion = false}) {
    return MaterialApp(
      // 배경색을 AppColors 토큰에서 읽으므로 테마가 필요하다
      theme: AppTheme.light,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        // 광원 크기가 `.w`를 쓰므로 앱과 같은 환경이 필요하다.
        // 없으면 LateError로 위젯 빌드 자체가 실패한다.
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) =>
              const Scaffold(body: AuroraBackground()),
        ),
      ),
    );
  }

  /// 큰 원(Eclipse)의 현재 자리
  Offset eclipseAt(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(AuroraBackground.eclipseKey));

  Offset planetAt(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(AuroraBackground.planetKey));

  testWidgets('시간이 지나면 원이 움직인다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    final before = eclipseAt(tester);
    // 주기가 28초라 몇 초로는 눈에 띄게 움직인다
    await tester.pump(const Duration(seconds: 5));
    final after = eclipseAt(tester);

    expect(after, isNot(before));

    // 무한 반복이라 테스트를 끝내려면 멈춰야 한다
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('애니메이션 끄기를 켜면 움직이지 않고 시안 자리에 선다', (tester) async {
    // 움직임이 어지럼증을 유발하는 사용자가 있다
    await tester.pumpWidget(wrap(reduceMotion: true));
    await tester.pump();

    final before = eclipseAt(tester);
    await tester.pump(const Duration(seconds: 5));

    expect(eclipseAt(tester), before);
    // 시안 238:1729 Eclipse (11.2, 225.3) · 238:1730 Planet (120.4, 204)
    expect(before.dx, closeTo(11.2, 0.5));
    expect(before.dy, closeTo(225.3, 0.5));
    expect(planetAt(tester).dx, closeTo(120.4, 0.5));
    expect(planetAt(tester).dy, closeTo(204, 0.5));
    // 돌고 있으면 여기서 타임아웃난다
    await tester.pumpAndSettle();
  });

  testWidgets('두 원이 시안 자리에서 멀리 떠나지 않는다', (tester) async {
    // 디자이너 요청 — 구석구석 떠다니면 광원이 따로 노는 것처럼 보인다.
    // 원 배치는 시안 그대로 두고 그 둘레만 살짝 돈다 (#380).
    await tester.pumpWidget(wrap());
    await tester.pump();

    for (var elapsed = 0; elapsed < 40; elapsed += 4) {
      final e = eclipseAt(tester);
      final p = planetAt(tester);
      expect((e - const Offset(11.2, 225.3)).distance, lessThan(30));
      expect((p - const Offset(120.4, 204)).distance, lessThan(30));
      await tester.pump(const Duration(seconds: 4));
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('원을 두 개 그린다 — 시안 Gradient 그룹이 Eclipse·Planet 둘이다', (tester) async {
    await tester.pumpWidget(wrap(reduceMotion: true));
    await tester.pump();

    expect(find.byKey(AuroraBackground.eclipseKey), findsOneWidget);
    expect(find.byKey(AuroraBackground.planetKey), findsOneWidget);
    // 시안 크기 — 356.7 · 261 (393 폭 기준)
    expect(
      tester.getSize(find.byKey(AuroraBackground.eclipseKey)).width,
      closeTo(356.7, 0.5),
    );
    expect(
      tester.getSize(find.byKey(AuroraBackground.planetKey)).width,
      closeTo(261, 0.5),
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
