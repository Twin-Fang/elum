import 'package:elum/core/layout/app_layout.dart';
import 'package:elum/core/layout/layout_metrics.dart';
import 'package:elum/core/layout/window_size_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 창 크기 > 등급·배율 계산 (순수 함수).
/// 깨지면: 태블릿에서 폭만 커져 찌그러지거나, 폰 배율이 달라져 모든 화면이 흔들린다.
void main() {
  const baseDesignSize = Size(393, 852);

  LayoutMetrics metricsOf(double width, double height) =>
      LayoutMetrics.fromWindowSize(Size(width, height));

  group('창 등급 경계 (폭 기준)', () {
    test('599 는 compact, 600 은 medium', () {
      expect(metricsOf(599, 1000).sizeClass, WindowSizeClass.compact);
      expect(metricsOf(600, 960).sizeClass, WindowSizeClass.medium);
    });

    test('839 는 medium, 840 은 expanded', () {
      expect(metricsOf(839, 1000).sizeClass, WindowSizeClass.medium);
      expect(metricsOf(840, 900).sizeClass, WindowSizeClass.expanded);
    });
  });

  group('compact 는 현행 그대로', () {
    test('393x852 는 배율을 덮지 않고 디자인 크기도 그대로', () {
      final metrics = metricsOf(393, 852);

      expect(metrics.isScaleOverridden, isFalse);
      expect(metrics.scale, 1.0);
      expect(metrics.designSizeFor(baseDesignSize), baseDesignSize);
    });

    test('큰 폰(430x932)과 작은 폰(320x568)도 덮지 않는다', () {
      for (final size in const [Size(430, 932), Size(320, 568)]) {
        final metrics = metricsOf(size.width, size.height);
        expect(metrics.isScaleOverridden, isFalse, reason: '$size');
        expect(metrics.designSizeFor(baseDesignSize), baseDesignSize);
      }
    });
  });

  group('medium · expanded 는 폭과 높이가 같은 배율', () {
    test('1194x834 가로: 높이에 맞춰 0.979', () {
      final metrics = metricsOf(1194, 834);
      final designSize = metrics.designSizeFor(baseDesignSize);

      expect(metrics.sizeClass, WindowSizeClass.expanded);
      expect(metrics.isLandscape, isTrue);
      expect(metrics.isScaleOverridden, isTrue);
      expect(metrics.scale, closeTo(834 / 852, 1e-9));
      // .w = 창폭 / 디자인폭, .h = 창높이 / 디자인높이 가 같아야 찌그러지지 않는다
      expect(1194 / designSize.width, closeTo(metrics.scale, 1e-9));
      expect(834 / designSize.height, closeTo(metrics.scale, 1e-9));
    });

    test('744x1133 세로: 상한 1.3 에서 멈춘다', () {
      final metrics = metricsOf(744, 1133);

      expect(metrics.sizeClass, WindowSizeClass.medium);
      expect(metrics.isLandscape, isFalse);
      expect(metrics.scale, 1.3);
      expect(metrics.phoneColumnWidthPixels, closeTo(393 * 1.3, 1e-9));
    });

    test('960x600: 하한 0.8 에서 멈춘다', () {
      final metrics = metricsOf(960, 600);

      expect(metrics.scale, 0.8);
      expect(metrics.isShortHeight, isFalse);
    });

    test('1366x1024: 높이 기준 1.202', () {
      expect(metricsOf(1366, 1024).scale, closeTo(1024 / 852, 1e-9));
    });
  });

  group('높이가 모자란 창', () {
    test('1024x320 은 isShortHeight', () {
      expect(metricsOf(1024, 320).isShortHeight, isTrue);
    });

    test('479 는 모자라고 480 은 아니다', () {
      expect(metricsOf(1024, 479).isShortHeight, isTrue);
      expect(metricsOf(1024, 480).isShortHeight, isFalse);
    });
  });

  group('폰 비율 열 폭', () {
    test('창 폭보다 넓어지지 않는다', () {
      // 600x960: s = 1.127 이라 393*s = 443 이지만 창이 600 이라 그대로
      expect(metricsOf(600, 960).phoneColumnWidthPixels, lessThanOrEqualTo(600));
      // 극단: 열이 창보다 넓으면 창 폭으로 자른다
      expect(
        LayoutMetrics.fromWindowSize(const Size(600, 3000))
            .phoneColumnWidthPixels,
        lessThanOrEqualTo(600),
      );
    });
  });

  group('방어', () {
    test('Size.zero 는 compact 이고 예외가 없다', () {
      final metrics = LayoutMetrics.fromWindowSize(Size.zero);

      expect(metrics.sizeClass, WindowSizeClass.compact);
      expect(metrics.isScaleOverridden, isFalse);
      expect(metrics.designSizeFor(baseDesignSize), baseDesignSize);
    });

    test('폭 0 높이만 있어도 compact', () {
      expect(metricsOf(0, 800).sizeClass, WindowSizeClass.compact);
    });
  });

  group('토큰', () {
    test('좌우 여백은 등급이 클수록 넓다', () {
      const layout = AppLayout.standard;

      expect(layout.pageMarginFor(WindowSizeClass.compact), 24);
      expect(layout.pageMarginFor(WindowSizeClass.medium), 40);
      expect(layout.pageMarginFor(WindowSizeClass.expanded), 56);
    });
  });
}
