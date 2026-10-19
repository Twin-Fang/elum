import 'package:elum/core/layout/adaptive_screen_scale.dart';
import 'package:elum/core/layout/adaptive_scope.dart';
import 'package:elum/core/layout/layout_context_ext.dart';
import 'package:elum/core/layout/window_size_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// 창 크기 > ScreenUtil 배율 연결 (P0 스파이크).
/// 깨지면: 태블릿 회전·분할 보기에서 `.w` 만 커지고 `.h` 는 그대로라 화면이 찌그러진다.
const _baseDesignSize = Size(393, 852);

/// 빌드될 때마다 `100.w` / `100.h` 를 기록하는 탐침
class ScaleProbe extends StatelessWidget {
  const ScaleProbe({super.key, required this.onBuilt});

  final void Function(double width, double height, WindowSizeClass sizeClass)
  onBuilt;

  @override
  Widget build(BuildContext context) {
    onBuilt(100.w, 100.h, context.sizeClass);
    return const SizedBox.shrink();
  }
}

void main() {
  late double measuredWidth;
  late double measuredHeight;
  late WindowSizeClass measuredSizeClass;

  void recordMeasurement(double width, double height, WindowSizeClass c) {
    measuredWidth = width;
    measuredHeight = height;
    measuredSizeClass = c;
  }

  Future<void> pumpAdaptive(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AdaptiveScreenScale(
          baseDesignSize: _baseDesignSize,
          builder: (context, child) => ScaleProbe(onBuilt: recordMeasurement),
        ),
      ),
    );
    await tester.pump();
  }

  /// 기존 앱 구성(ScreenUtilInit 만) 에서 같은 값을 잰다
  Future<({double width, double height})> measurePlainScreenUtil(
    WidgetTester tester,
    Size size,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    double? width;
    double? height;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ScreenUtilInit(
          designSize: _baseDesignSize,
          minTextAdapt: true,
          builder: (context, child) => ScaleProbe(
            onBuilt: (w, h, _) {
              width = w;
              height = h;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return (width: width!, height: height!);
  }

  group('compact 는 기존 ScreenUtilInit 과 같다 (폰 회귀 0)', () {
    for (final size in const [
      Size(393, 852),
      Size(430, 932),
      Size(320, 568),
      Size(375, 667),
    ]) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()}', (
        tester,
      ) async {
        final plain = await measurePlainScreenUtil(tester, size);

        await pumpAdaptive(tester, size);

        expect(measuredSizeClass, WindowSizeClass.compact);
        expect(measuredWidth, closeTo(plain.width, 1e-9));
        expect(measuredHeight, closeTo(plain.height, 1e-9));
      });
    }
  });

  group('medium · expanded 는 .w 와 .h 가 같은 배율', () {
    testWidgets('1194x834 가로: 0.979', (tester) async {
      await pumpAdaptive(tester, const Size(1194, 834));

      expect(measuredSizeClass, WindowSizeClass.expanded);
      expect(measuredWidth, closeTo(100 * 834 / 852, 0.01));
      expect(measuredHeight, closeTo(100 * 834 / 852, 0.01));
    });

    testWidgets('744x1133 세로: 상한 1.3', (tester) async {
      await pumpAdaptive(tester, const Size(744, 1133));

      expect(measuredSizeClass, WindowSizeClass.medium);
      expect(measuredWidth, closeTo(130, 0.01));
      expect(measuredHeight, closeTo(130, 0.01));
    });
  });

  group('창 크기가 바뀌면 배율이 따라온다 (회전·분할 보기)', () {
    testWidgets('폰 세로 > 아이패드 가로 > 폰 세로', (tester) async {
      await pumpAdaptive(tester, const Size(393, 852));
      expect(measuredWidth, closeTo(100, 1e-9));

      tester.view.physicalSize = const Size(1194, 834);
      await tester.pump();
      expect(measuredSizeClass, WindowSizeClass.expanded);
      expect(measuredWidth, closeTo(100 * 834 / 852, 0.01));
      expect(measuredHeight, closeTo(100 * 834 / 852, 0.01));

      tester.view.physicalSize = const Size(393, 852);
      await tester.pump();
      expect(measuredSizeClass, WindowSizeClass.compact);
      expect(measuredWidth, closeTo(100, 1e-9));
      expect(measuredHeight, closeTo(100, 1e-9));
    });
  });

  testWidgets('AdaptiveScope 가 현재 창의 metrics 를 내려준다', (tester) async {
    await pumpAdaptive(tester, const Size(744, 1133));

    final context = tester.element(find.byType(ScaleProbe));
    final metrics = AdaptiveScope.maybeOf(context);

    expect(metrics, isNotNull);
    expect(metrics!.sizeClass, WindowSizeClass.medium);
    expect(context.layoutMetrics, same(metrics));
  });

  testWidgets('스코프 없이도 context.layoutMetrics 는 MediaQuery 로 계산한다', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1194, 834);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late WindowSizeClass sizeClass;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            sizeClass = context.sizeClass;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(sizeClass, WindowSizeClass.expanded);
  });
}
