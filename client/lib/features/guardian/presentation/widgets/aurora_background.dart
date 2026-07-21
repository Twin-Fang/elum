import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/theme_context_ext.dart';

/// 천천히 흐르는 컬러 블러 배경.
///
/// Figma `보호자_새로운 일과 만들기`(238:1643)의 `Gradient`(238:1728)를 재현한다.
/// 원본은 blur 200px·100px 원이 겹친 정적 SVG지만, 화면에서는 **아주 천천히
/// 움직여야** 한다. 그래서 에셋이 아니라 코드로 그린다.
///
/// 위에 얹는 칩·입력창이 `backdropFilter`를 쓰므로, 배경이 움직이면 유리 너머
/// 색이 저절로 흐른다. 그쪽은 따로 애니메이션하지 않는다.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key});

  /// 각 원의 왕복 주기.
  ///
  /// **서로 나누어떨어지지 않게 잡는다.** 20·40초처럼 배수 관계면 40초마다
  /// 셋이 정확히 같은 자리로 돌아와 패턴이 눈에 보인다. (docs/motion.md)
  static const _periods = [
    Duration(seconds: 28),
    Duration(seconds: 34),
    Duration(seconds: 22),
  ];

  /// 시작 위치와 끝 위치 (Alignment 기준).
  /// 화면 밖까지 나가야 가장자리가 비지 않는다.
  static const _paths = [
    (Alignment(-0.9, -0.7), Alignment(0.5, 0.2)),
    (Alignment(0.9, -0.3), Alignment(-0.4, 0.6)),
    (Alignment(-0.2, 0.8), Alignment(0.7, -0.5)),
  ];

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with TickerProviderStateMixin {
  /// 원마다 주기가 달라야 하므로 컨트롤러를 따로 둔다.
  /// 하나로 묶고 Interval을 쓰면 주기를 독립적으로 줄 수 없다.
  late final List<AnimationController> _controllers = [
    for (final period in AuroraBackground._periods)
      AnimationController(vsync: this, duration: period),
  ];

  bool _isRunning = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 접근성 설정은 앱 실행 중에도 바뀔 수 있다
    _syncWithAccessibility();
  }

  /// 동작 줄이기를 켠 사용자에게는 애니메이션을 돌리지 않는다.
  ///
  /// 보이지 않아도 컨트롤러가 돌면 배터리를 쓴다. 정지만 하는 게 아니라
  /// 아예 시작하지 않는다. (docs/motion.md 접근성)
  void _syncWithAccessibility() {
    final shouldRun = !MediaQuery.disableAnimationsOf(context);
    if (shouldRun == _isRunning) return;

    _isRunning = shouldRun;
    for (final controller in _controllers) {
      if (shouldRun) {
        controller.repeat(reverse: true);
      } else {
        controller
          ..stop()
          // 정지 위치가 제각각이면 화면이 어색하다. 시작점으로 되돌린다.
          ..value = 0;
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 배경만 다시 그리게 격리한다. 이게 없으면 원이 움직일 때마다
    // 위에 얹힌 텍스트·칩까지 재페인트된다.
    return RepaintBoundary(
      child: Stack(
        children: [
          for (var i = 0; i < _controllers.length; i++)
            AnimatedBuilder(
              animation: _controllers[i],
              builder: (context, _) {
                final (from, to) = AuroraBackground._paths[i];
                final t = Curves.easeInOut.transform(_controllers[i].value);
                return Align(
                  alignment: Alignment.lerp(from, to, t)!,
                  child: _blurredCircle(_auroraColors(context)[i]),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Figma 그라데이션에서 뽑은 세 색. 토큰을 경유한다.
  List<Color> _auroraColors(BuildContext context) {
    final colors = context.colors;
    return [colors.auroraMint, colors.auroraViolet, colors.auroraYellow];
  }

  Widget _blurredCircle(Color color) {
    return ImageFiltered(
      // Figma는 blur 100~200px이다. 여기서는 원 크기 대비로 잡는다.
      imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // 완전 불투명하면 세 색이 겹칠 때 탁해진다
          color: color.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
