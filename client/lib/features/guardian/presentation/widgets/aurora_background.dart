import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 일과 만들기 화면마다 깔리는 배경 색 (#380).
///
/// 시안은 화면마다 **같은 두 원(`Gradient` 그룹)을 복제해 색만 바꿔** 그렸다.
/// 그래서 색은 화면이 정하고, 모양·움직임은 흐름 전체가 하나를 쓴다.
enum AuroraTone {
  /// 입력(238:1643)·로딩·추가질문 — 민트·보라·노랑.
  ///
  /// 시안의 로딩(262:4569)·추가질문(262:4766)은 색이 또 다르지만 앱은 지금까지
  /// 입력 색을 같이 써 왔다. 이번 범위가 아니다 (#380 확인 필요 4).
  prepare,

  /// 보상 설정(1082:4709) — 분홍.
  reward,

  /// 오로라 없음 — 카드확인(262:5124)은 단색 배경이다.
  none,
}

/// 오로라 세 원의 색과 세기.
///
/// **색과 세기를 따로 보간한다.** `none`을 투명 검정으로 두고 색째 섞으면
/// 가라앉는 도중 원이 잿빛으로 탁해진다. 세기만 줄이면 색은 그대로 옅어진다.
@immutable
class AuroraPalette {
  const AuroraPalette(this.colors, {this.strength = 1});

  /// 세 원의 색 (알파 없는 원색). 순서는 Eclipse 시작 · Eclipse 끝 · Planet 시작.
  final List<Color> colors;

  /// 0이면 보이지 않는다, 1이면 시안 세기.
  final double strength;

  /// 완전 불투명하면 세 색이 겹칠 때 탁해진다 — 원마다 이만큼만 칠한다.
  static const _alpha = 0.55;

  static AuroraPalette of(AppColors colors, AuroraTone tone) => switch (tone) {
    AuroraTone.prepare => AuroraPalette([
      colors.auroraMint,
      colors.auroraViolet,
      colors.auroraYellow,
    ]),
    AuroraTone.reward => AuroraPalette([
      colors.auroraRewardViolet,
      colors.auroraRewardPink,
      colors.auroraRewardRose,
    ]),
    // 색은 아무거나 둔다 — 세기가 0이면 보간할 때 상대편 색을 쓴다.
    AuroraTone.none => AuroraPalette([
      colors.auroraMint,
      colors.auroraViolet,
      colors.auroraYellow,
    ], strength: 0),
  };

  /// 실제로 칠하는 색 (알파 포함).
  List<Color> get visibleColors => [
    for (final c in colors) c.withValues(alpha: _alpha * strength),
  ];

  /// 두 팔레트 사이.
  ///
  /// 한쪽 세기가 0이면 그쪽 색은 뜻이 없다 — **상대편 색을 빌려** 세기만
  /// 옮긴다. 분홍이 가라앉을 때 분홍 그대로 옅어지고, 떠오를 때도 처음부터
  /// 분홍이다.
  static AuroraPalette lerp(AuroraPalette a, AuroraPalette b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    final from = a.strength == 0 ? b.colors : a.colors;
    final to = b.strength == 0 ? a.colors : b.colors;
    return AuroraPalette(
      [for (var i = 0; i < from.length; i++) Color.lerp(from[i], to[i], t)!],
      strength: a.strength + (b.strength - a.strength) * t,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuroraPalette &&
      other.strength == strength &&
      listEquals(other.colors, colors);

  @override
  int get hashCode => Object.hash(strength, Object.hashAll(colors));
}

class _AuroraPaletteTween extends Tween<AuroraPalette> {
  _AuroraPaletteTween({super.end});

  @override
  AuroraPalette lerp(double t) => AuroraPalette.lerp(begin!, end!, t);
}

/// 천천히 흐르는 컬러 블러 배경.
///
/// Figma `보호자_새로운 일과 만들기`(238:1643)의 `Gradient`(238:1728)를 재현한다.
/// 원본은 blur 200px·100px 원이 겹친 정적 SVG지만, 화면에서는 **아주 천천히
/// 움직여야** 한다. 그래서 에셋이 아니라 코드로 그린다.
///
/// 위에 얹는 칩·입력창이 `backdropFilter`를 쓰므로, 배경이 움직이면 유리 너머
/// 색이 저절로 흐른다. 그쪽은 따로 애니메이션하지 않는다.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, this.tone = AuroraTone.prepare});

  /// 깔 색. **바뀌면 그 자리에서 번진다** — 원은 멈추지 않고 색만 옮겨 간다.
  final AuroraTone tone;

  /// 원 하나하나 (테스트가 전환 중간의 색을 재려고 찾는다).
  @visibleForTesting
  static const circleKey = ValueKey('auroraCircle');

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
    // 동작 줄이기면 색도 즉시 바꾼다 — 번지는 700ms 동안 화면이 계속 변한다.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // 배경만 다시 그리게 격리한다. 이게 없으면 원이 움직일 때마다
    // 위에 얹힌 텍스트·칩까지 재페인트된다.
    return RepaintBoundary(
      // **새 색은 지금 보이는 색에서 출발한다.** 번지는 도중에 되돌아가도
      // 끝값으로 건너뛰지 않고 그 자리에서 방향만 바꾼다 (TweenAnimationBuilder).
      child: TweenAnimationBuilder<AuroraPalette>(
        tween: _AuroraPaletteTween(
          end: AuroraPalette.of(context.colors, widget.tone),
        ),
        duration: reduceMotion ? Duration.zero : AppMotion.ambient,
        // 시작과 끝이 모두 느린 곡선 — 첫 프레임에 색이 튀지 않고 끝에서
        // 스르르 멎는다. 끝이 급하면 "다 바뀌었다"는 순간이 눈에 걸린다.
        curve: AppMotion.standard,
        builder: (context, palette, _) {
          final colors = palette.visibleColors;
          return Stack(
            children: [
              for (var i = 0; i < _controllers.length; i++)
                AnimatedBuilder(
                  animation: _controllers[i],
                  builder: (context, _) {
                    return Align(
                      alignment: _alignmentFor(i),
                      child: _blurredCircle(colors[i]),
                    );
                  },
                ),
            ],
          );
        },
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
        key: AuroraBackground.circleKey,
        width: diameter,
        height: diameter,
        // 알파는 팔레트가 이미 담았다 (AuroraPalette.visibleColors).
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
