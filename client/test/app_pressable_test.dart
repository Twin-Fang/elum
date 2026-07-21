import 'package:elum/core/theme/app_motion.dart';
import 'package:elum/core/widgets/app_pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 눌림 반응 위젯 테스트.
///
/// 토스 방식 — **누를 때는 즉각 줄고, 뗄 때만 물리적으로 복귀한다.**
/// 누르는 순간에도 애니메이션을 넣으면 반응이 굼떠 보인다. (docs/motion.md)
void main() {
  /// 현재 적용된 scale 값을 읽는다
  double currentScale(WidgetTester tester) {
    final transform = tester.widget<Transform>(
      find.descendant(
        of: find.byType(AppPressable),
        matching: find.byType(Transform),
      ),
    );
    // Matrix4의 x축 스케일 성분
    return transform.transform.storage[0];
  }

  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  group('AppPressable — 눌림 반응', () {
    testWidgets('누르면 즉시 줄어든다', (tester) async {
      await tester.pumpWidget(
        wrap(AppPressable(onTap: () {}, child: const Text('버튼'))),
      );

      expect(currentScale(tester), 1.0);

      final gesture = await tester.startGesture(tester.getCenter(find.text('버튼')));
      // pump 한 번이면 충분하다 — 누름은 애니메이션이 아니라 즉시 반영이다
      await tester.pump();

      expect(currentScale(tester), AppPressable.scaleButton);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('떼면 원래 크기로 돌아온다', (tester) async {
      await tester.pumpWidget(
        wrap(AppPressable(onTap: () {}, child: const Text('버튼'))),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('버튼')));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(currentScale(tester), closeTo(1.0, 0.001));
    });

    testWidgets('탭하면 onTap이 불린다', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        wrap(AppPressable(onTap: () => tapped++, child: const Text('버튼'))),
      );

      await tester.tap(find.text('버튼'));
      await tester.pumpAndSettle();

      expect(tapped, 1);
    });

    testWidgets('onTap이 null이면 눌러도 줄어들지 않는다', (tester) async {
      // 비활성 버튼이 반응하면 눌리는 줄 안다
      await tester.pumpWidget(
        wrap(const AppPressable(onTap: null, child: Text('버튼'))),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('버튼')));
      await tester.pump();

      expect(currentScale(tester), 1.0);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('밖으로 끌어내면 취소되고 복귀한다', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        wrap(AppPressable(onTap: () => tapped++, child: const Text('버튼'))),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('버튼')));
      await tester.pump();
      // 손가락을 위젯 밖으로 옮기면 탭이 아니다
      await gesture.moveTo(const Offset(5, 5));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(tapped, 0);
      expect(currentScale(tester), closeTo(1.0, 0.001));
    });

    testWidgets('면적이 넓을수록 덜 줄인다', (tester) async {
      // 큰 카드를 아이콘만큼 줄이면 과장돼 보인다
      expect(AppPressable.scaleCard, greaterThan(AppPressable.scaleButton));
      expect(AppPressable.scaleButton, greaterThan(AppPressable.scaleIcon));
    });

    testWidgets('scaleDown을 직접 지정할 수 있다', (tester) async {
      await tester.pumpWidget(
        wrap(
          AppPressable(
            onTap: () {},
            scaleDown: AppPressable.scaleIcon,
            child: const Text('아이콘'),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('아이콘')));
      await tester.pump();

      expect(currentScale(tester), AppPressable.scaleIcon);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('애니메이션 끄기를 켜면 크기가 변하지 않는다', (tester) async {
      // 움직임에 민감한 사용자가 있다 (docs/motion.md 접근성)
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: AppPressable(onTap: () {}, child: const Text('버튼')),
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('버튼')));
      await tester.pump();

      expect(currentScale(tester), 1.0);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('애니메이션을 꺼도 탭은 동작한다', (tester) async {
      // 반응만 없앨 뿐 기능을 막으면 안 된다
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: AppPressable(
                  onTap: () => tapped++,
                  child: const Text('버튼'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('버튼'));
      await tester.pumpAndSettle();

      expect(tapped, 1);
    });
  });

  group('AppMotion 토큰', () {
    test('Duration이 업계 기준(100~500ms) 안에 있다', () {
      for (final d in [
        AppMotion.instant,
        AppMotion.fast,
        AppMotion.normal,
        AppMotion.slow,
        AppMotion.emphasis,
      ]) {
        expect(d.inMilliseconds, inInclusiveRange(100, 500));
      }
    });

    test('아동 화면 최소 전환은 300ms 이상이다', () {
      // 급격한 전환은 인지 부하가 크다
      expect(AppMotion.childMinimum.inMilliseconds, greaterThanOrEqualTo(300));
    });

    test('stagger는 긴 목록에서 무한정 늘어나지 않는다', () {
      // 100번째 아이템이 3초 뒤에 뜨면 안 된다
      final late_ = AppMotion.staggerFor(100);
      expect(late_, AppMotion.staggerFor(10));
      expect(late_.inMilliseconds, lessThanOrEqualTo(300));
    });

    test('stagger는 순서대로 늘어난다', () {
      expect(
        AppMotion.staggerFor(2).inMilliseconds,
        greaterThan(AppMotion.staggerFor(1).inMilliseconds),
      );
    });
  });
}
