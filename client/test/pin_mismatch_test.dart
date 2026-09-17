import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elum/core/theme/app_motion.dart';
import 'package:elum/core/widgets/app_shake.dart';

/// 틀린 입력은 색이 아니라 움직임으로 알린다.
/// 동작 줄이기가 켜져 있으면 흔들지 않는다 — 전정기관이 예민한 사용자를 위한 것이다.
void main() {
  // 진폭이 .w를 거치므로 ScreenUtil이 초기화돼 있어야 한다
  Widget host({required int trigger, bool reduceMotion = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.ltr,
          child: AppShake(
            trigger: trigger,
            child: const SizedBox(width: 40, height: 10),
          ),
        ),
      ),
    );
  }

  /// 멈춰 있을 때는 Transform을 걸지 않으므로, 없으면 어긋남이 0이라는 뜻이다.
  Offset shift(WidgetTester tester) {
    final found = find.descendant(
      of: find.byType(AppShake),
      matching: find.byType(Transform),
    );
    if (found.evaluate().isEmpty) return Offset.zero;
    final t = tester.widget<Transform>(found.first);
    return Offset(t.transform.getTranslation().x, t.transform.getTranslation().y);
  }

  testWidgets('평소에는 움직이지 않는다', (tester) async {
    await tester.pumpWidget(host(trigger: 0));
    expect(shift(tester), Offset.zero);
  });

  testWidgets('트리거가 바뀌면 흔들린다', (tester) async {
    await tester.pumpWidget(host(trigger: 0));
    await tester.pumpWidget(host(trigger: 1));

    await tester.pump(AppMotion.shake ~/ 8);
    expect(shift(tester).dx, isNot(0), reason: '흔들리는 중이어야 한다');

    // 끝나면 정확히 제자리로 — 남으면 점 위치가 틀어진 채 굳는다
    await tester.pumpAndSettle();
    expect(shift(tester), Offset.zero);
  });

  testWidgets('스윙이 갈수록 작아진다 — 등폭으로 튕기지 않는다', (tester) async {
    await tester.pumpWidget(host(trigger: 0));
    await tester.pumpWidget(host(trigger: 1));

    // 각 스윙의 정점 부근을 훑어 최대 진폭을 구간별로 모은다
    final swings = <double>[];
    var maxInWindow = 0.0;
    var lastSign = 0;
    const steps = 44;
    for (var i = 1; i <= steps; i++) {
      await tester.pump(AppMotion.shake ~/ steps);
      final dx = shift(tester).dx;
      final sign = dx == 0 ? lastSign : (dx > 0 ? 1 : -1);
      if (sign != lastSign && lastSign != 0) {
        swings.add(maxInWindow);
        maxInWindow = 0;
      }
      lastSign = sign;
      maxInWindow = math.max(maxInWindow, dx.abs());
    }

    expect(swings.length, greaterThanOrEqualTo(3), reason: '여러 번 왕복해야 한다');
    for (var i = 1; i < swings.length; i++) {
      expect(swings[i], lessThan(swings[i - 1]),
          reason: '스윙 $i이 이전보다 커지면 감쇠가 아니다');
    }
  });

  testWidgets('동작 줄이기가 켜져 있으면 흔들지 않는다', (tester) async {
    await tester.pumpWidget(host(trigger: 0, reduceMotion: true));
    await tester.pumpWidget(host(trigger: 1, reduceMotion: true));

    await tester.pump(AppMotion.shake ~/ 8);
    expect(shift(tester), Offset.zero);
  });
}
