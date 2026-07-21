import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

  /// 세 광원이 모여 있을 중심.
  ///
  /// 화면 정중앙보다 살짝 위다 — Figma에서 빛이 제목 뒤에 모여 있다.
  static const _center = Alignment(0, -0.15);

  /// 중심에서 각 광원이 벗어나는 방향.
  ///
  /// 세 방향으로 살짝만 벌려 **서로 붙어 있는 덩어리**로 보이게 한다.
  /// 화면 구석으로 흩어지면 광원 셋이 따로 노는 것처럼 보인다.
  static const _offsets = [
    Offset(-0.30, -0.18),
    Offset(0.30, -0.10),
    Offset(0.05, 0.28),
  ];

  /// 각 광원이 중심 주위를 도는 반경 (Alignment 단위).
  ///
  /// 작게 잡아야 뭉쳐 있는 느낌이 유지된다. 크게 잡으면 다시 흩어진다.
  static const _wander = 0.14;

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
                return Align(
                  alignment: _alignmentFor(i),
                  child: _blurredCircle(_auroraColors(context)[i]),
                );
              },
            ),
        ],
      ),
    );
  }

  /// 광원 [i]의 현재 위치.
  ///
  /// 고정 중심에서 정해진 방향만큼 떨어진 자리를 기준으로, 그 주위를 작은
  /// 원을 그리며 돈다. 셋이 각자 다른 주기로 돌지만 **중심이 같아 뭉쳐 보인다.**
  ///
  /// 이전에는 화면 구석에서 구석으로 이동해 광원이 따로 노는 느낌이었다.
  Alignment _alignmentFor(int i) {
    // 컨트롤러가 reverse로 왕복하므로 0~1을 0~2π로 펴서 원운동을 만든다
    final angle = _controllers[i].value * 2 * math.pi;
    final base = AuroraBackground._offsets[i];

    return Alignment(
      AuroraBackground._center.x +
          base.dx +
          math.cos(angle) * AuroraBackground._wander,
      AuroraBackground._center.y +
          base.dy +
          math.sin(angle) * AuroraBackground._wander,
    );
  }

  /// Figma 그라데이션에서 뽑은 세 색. 토큰을 경유한다.
  List<Color> _auroraColors(BuildContext context) {
    final colors = context.colors;
    return [colors.auroraMint, colors.auroraViolet, colors.auroraYellow];
  }

  Widget _blurredCircle(Color color) {
    // 광원 위치는 [Alignment]가 화면 비율로 잡지만 **크기는 고정값**이라,
    // 큰 기기에서는 화면 대비 광원이 작아져 배경이 허전해진다.
    // Figma 260(393 폭 기준)을 `.w`로 환산해 비율을 유지한다.
    final diameter = 260.w;

    return ImageFiltered(
      // Figma는 blur 100~200px이다. 여기서는 원 크기 대비(약 27%)로 잡는다.
      // 원만 키우고 blur를 그대로 두면 가장자리가 선명해져 광원처럼 안 보인다.
      imageFilter: ImageFilter.blur(
        sigmaX: diameter * 0.27,
        sigmaY: diameter * 0.27,
      ),
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // 완전 불투명하면 세 색이 겹칠 때 탁해진다
          color: color.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
