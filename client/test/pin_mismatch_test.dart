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

  Offset shift(WidgetTester tester) {
    final t = tester.widget<Transform>(
      find.descendant(of: find.byType(AppShake), matching: find.byType(Transform)),
    );
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

  testWidgets('동작 줄이기가 켜져 있으면 흔들지 않는다', (tester) async {
    await tester.pumpWidget(host(trigger: 0, reduceMotion: true));
    await tester.pumpWidget(host(trigger: 1, reduceMotion: true));

    await tester.pump(AppMotion.shake ~/ 8);
    expect(shift(tester), Offset.zero);
  });
}
