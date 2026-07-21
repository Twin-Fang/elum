import 'package:elum/core/theme/app_motion.dart';
import 'package:elum/core/widgets/app_fade_slide_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// AppFadeSlideIn — 등장 연출 공통 위젯 (motion.md 명세).
///
/// delay 동안 투명하게 대기했다가 fade + slide up으로 나타난다.
/// delay를 Timer로 처리하면 dispose 후 콜백이 도는 사고가 나므로,
/// 컨트롤러 타임라인 방식인지(=dispose 후 예외 없음)도 함께 고정한다.
void main() {
  Widget wrap(Widget child) {
    return MaterialApp(home: Scaffold(body: Center(child: child)));
  }

  /// 대상 텍스트를 감싸는 Opacity의 현재 값. 없으면(등장 완료) null.
  double? opacityOf(WidgetTester tester, String text) {
    final finder = find.ancestor(
      of: find.text(text),
      matching: find.byType(Opacity),
    );
    if (finder.evaluate().isEmpty) return null;
    return tester.widget<Opacity>(finder.first).opacity;
  }

  testWidgets('시작 시점에는 투명하다', (tester) async {
    await tester.pumpWidget(wrap(const AppFadeSlideIn(child: Text('내용'))));

    // 첫 프레임 — 아직 등장 전
    expect(opacityOf(tester, '내용'), 0);
  });

  testWidgets('duration이 지나면 완전히 보이고 변환 오버헤드가 없다', (tester) async {
    await tester.pumpWidget(wrap(const AppFadeSlideIn(child: Text('내용'))));

    await tester.pump(AppMotion.normal);
    await tester.pump();

    // 등장 완료 후에는 Opacity/Transform 없이 child만 남는다
    expect(opacityOf(tester, '내용'), isNull);
    expect(find.text('내용'), findsOneWidget);
  });

  testWidgets('delay 동안은 투명하게 대기한다', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppFadeSlideIn(
          delay: Duration(milliseconds: 200),
          duration: Duration(milliseconds: 300),
          child: Text('내용'),
        ),
      ),
    );

    // delay 경계 직전까지는 투명해야 한다
    await tester.pump(const Duration(milliseconds: 190));
    expect(opacityOf(tester, '내용'), 0);

    // delay + duration이 지나면 완전히 보인다
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();
    expect(opacityOf(tester, '내용'), isNull);
  });

  testWidgets('등장 중에 dispose되어도 예외가 없다', (tester) async {
    await tester.pumpWidget(
      wrap(
        const AppFadeSlideIn(
          delay: Duration(milliseconds: 300),
          child: Text('내용'),
        ),
      ),
    );

    // delay 구간 한가운데서 위젯을 제거한다
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(wrap(const SizedBox()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
  });
}
