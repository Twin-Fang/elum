import 'package:elum/core/widgets/app_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 눌림 반응 위젯 테스트.
///
/// 토스 방식 — **누를 때는 즉각 줄고, 뗄 때만 물리적으로 복귀한다.**
/// 누르는 순간에도 애니메이션을 넣으면 반응이 굼떠 보인다. (docs/motion.md)
void main() {

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  // 그림만 있는 버튼은 이름을 주지 않으면 화면 낭독기에 "버튼"으로만 읽힌다 (#339).
  group('AppPressable — 읽을 이름', () {

    testWidgets('이름으로 눌러도 onTap 이 불린다', (tester) async {
      // 화면 낭독기는 좌표가 아니라 노드의 탭 동작을 부른다
      var tapped = 0;
      await tester.pumpWidget(
        wrap(AppPressable(
          onTap: () => tapped++,
          semanticLabel: '설정',
          child: const SizedBox(width: 40, height: 40),
        )),
      );

      tester.semantics.tap(find.semantics.byLabel('설정'));
      await tester.pumpAndSettle();

      expect(tapped, 1);
    });

  });

  group('AppPressable — 눌림 반응', () {

    testWidgets('탭하면 onTap이 불린다', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        wrap(AppPressable(onTap: () => tapped++, child: const Text('버튼'))),
      );

      await tester.tap(find.text('버튼'));
      await tester.pumpAndSettle();

      expect(tapped, 1);
    });

  });

}
