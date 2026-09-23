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
/// 값은 2026-09-23 덤프 기준이다 (섹션 `1049:4654`).
enum AuroraTone {
  /// 입력(238:1643) — 민트·보라·노랑.
  input,

  /// 보상 설정(1082:4709) — 분홍.
  reward,

  /// 준비 로딩(262:4569) — 옅은 연보라에 난초색.
  preparing,

  /// 추가질문(262:4766) — 파랑.
  question,

  /// 생성 로딩(262:4703) — 연두·산호·레몬.
  generating,

  /// 오로라 없음 — 카드확인(262:5124)은 단색 배경이다.
  none,
}

/// 오로라 두 원의 색·세기·자리.
///
/// **색과 세기를 따로 보간한다.** `none`을 투명 검정으로 두고 색째 섞으면
/// 가라앉는 도중 원이 잿빛으로 탁해진다. 세기만 줄이면 색은 그대로 옅어진다.
@immutable
class AuroraPalette {
  const AuroraPalette(
    this.colors, {
    required this.planetEnd,
    this.strength = 1,
    this.eclipseEndAlpha = 0.46,
    this.top = inputTop,
  });

  /// 세 색 (알파 없는 원색). 순서는 Eclipse 시작 · Eclipse 끝 · Planet 시작.
  final List<Color> colors;

  /// 작은 원(Planet) 아래 끝 — 투명한 색. **투명이어도 색이 보인다**: 그라데이션이
  /// 두 색 사이를 지나며 이 색을 섞는다(노랑 → 투명 하늘 = 가운데가 연두).
  /// 보상만 진분홍이고 나머지는 하늘이다. 하늘로 두면 분홍이 가운데서 연보라로 샌다.
  final Color planetEnd;

  /// 0이면 보이지 않는다, 1이면 시안 세기.
  final double strength;

  /// 큰 원(Eclipse) 아래 끝의 불투명도. 시안은 46% 로 흐려지는데, 준비 로딩만
  /// 단색으로 칠해 끝까지 100% 다.
  final double eclipseEndAlpha;

  /// 두 원 묶음(시안 `Gradient` 그룹)의 윗변 y — 852 높이 기준.
  final double top;

  /// 입력·보상의 그룹 윗변. 입력 화면이 40 올라가며(#380 결정 5) 함께 올라갔다.
  static const inputTop = 204.0;

  /// 로딩·추가질문의 그룹 윗변 — 제목이 285 에 있는 화면들이다.
  static const loadingTop = 244.0;

  static AuroraPalette of(AppColors colors, AuroraTone tone) => switch (tone) {
    AuroraTone.input => AuroraPalette([
      colors.auroraMint,
      colors.auroraViolet,
      colors.auroraYellow,
    ], planetEnd: colors.auroraPlanetFade),
    AuroraTone.reward => AuroraPalette([
      colors.auroraRewardViolet,
      colors.auroraRewardPink,
      colors.auroraRewardRose,
    ], planetEnd: colors.auroraRewardFade),
    AuroraTone.preparing => AuroraPalette(
      [
        colors.auroraPreparingHaze,
        colors.auroraPreparingHaze,
        colors.auroraPreparingOrchid,
      ],
      planetEnd: colors.auroraPlanetFade,
      // 시안 Eclipse 가 그라데이션이 아니라 단색이다 (262:4571)
      eclipseEndAlpha: 1,
      top: loadingTop,
    ),
    AuroraTone.question => AuroraPalette(
      [
        colors.auroraQuestionPeri,
        colors.auroraQuestionSky,
        colors.auroraQuestionIndigo,
      ],
      planetEnd: colors.auroraPlanetFade,
      top: loadingTop,
    ),
    AuroraTone.generating => AuroraPalette(
      [
        colors.auroraGeneratingMint,
        colors.auroraGeneratingCoral,
        colors.auroraGeneratingLemon,
      ],
      planetEnd: colors.auroraPlanetFade,
      top: loadingTop,
    ),
    // 색·자리는 아무거나 둔다 — 세기가 0이면 보간할 때 상대편 값을 쓴다.
    AuroraTone.none => AuroraPalette(
      [colors.auroraMint, colors.auroraViolet, colors.auroraYellow],
      planetEnd: colors.auroraPlanetFade,
      strength: 0,
    ),
  };

  /// 실제로 칠하는 색 (알파 포함) — Eclipse 시작 · Eclipse 끝 · Planet 시작.
  List<Color> get visibleColors => [
    colors[0].withValues(alpha: strength),
    colors[1].withValues(alpha: eclipseEndAlpha * strength),
    colors[2].withValues(alpha: strength),
  ];

  /// 두 팔레트 사이.
  ///
  /// 한쪽 세기가 0이면 그쪽 색·자리는 뜻이 없다 — **상대편 값을 빌려** 세기만
  /// 옮긴다. 분홍이 가라앉을 때 분홍 그대로 옅어지고, 떠오를 때도 처음부터
  /// 분홍이다. 자리도 그 자리에서 떠오른다.
  static AuroraPalette lerp(AuroraPalette a, AuroraPalette b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    final from = a.strength == 0 ? b : a;
    final to = b.strength == 0 ? a : b;
    double mix(double x, double y) => x + (y - x) * t;
    return AuroraPalette(
      [
        for (var i = 0; i < from.colors.length; i++)
          Color.lerp(from.colors[i], to.colors[i], t)!,
      ],
      planetEnd: Color.lerp(from.planetEnd, to.planetEnd, t)!,
      strength: mix(a.strength, b.strength),
      eclipseEndAlpha: mix(from.eclipseEndAlpha, to.eclipseEndAlpha),
      top: mix(from.top, to.top),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuroraPalette &&
      other.strength == strength &&
      other.eclipseEndAlpha == eclipseEndAlpha &&
      other.top == top &&
      other.planetEnd == planetEnd &&
      listEquals(other.colors, colors);

  @override
  int get hashCode =>
      Object.hash(strength, eclipseEndAlpha, top, planetEnd, Object.hashAll(colors));
}

class _AuroraPaletteTween extends Tween<AuroraPalette> {
  _AuroraPaletteTween({super.end});

  @override
  AuroraPalette lerp(double t) => AuroraPalette.lerp(begin!, end!, t);
}

/// 천천히 흐르는 컬러 블러 배경.
///
/// 시안 `Gradient` 그룹(입력 238:1728 등)을 그대로 옮긴다 — **큰 원(Eclipse)과
/// 작은 원(Planet) 둘**이고, 각자 위에서 아래로 흐려지는 선형 그라데이션에
/// 레이어 블러(200 · 100)가 걸려 있다. 시안은 정지된 한 장이지만 화면에서는
/// **아주 천천히 떠다녀야** 한다. 그래서 에셋이 아니라 코드로 그린다.
///
/// 위에 얹는 칩·입력창이 `backdropFilter`를 쓰므로, 배경이 움직이면 유리 너머
/// 색이 저절로 흐른다. 그쪽은 따로 애니메이션하지 않는다.
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, this.tone = AuroraTone.input});

  /// 깔 색. **바뀌면 그 자리에서 번진다** — 원은 멈추지 않고 색·자리만 옮겨 간다.
  final AuroraTone tone;

  /// 두 원 (테스트가 전환 중간의 색을 재려고 찾는다).
  @visibleForTesting
  static const eclipseKey = ValueKey('auroraEclipse');
  @visibleForTesting
  static const planetKey = ValueKey('auroraPlanet');

  /// 두 원 묶음 — 그룹 윗변이 입력 자리(204)에서 얼마나 내려왔는지 잰다.
  @visibleForTesting
  static const groupKey = ValueKey('auroraGroup');

  /// 각 원의 왕복 주기.
  ///
  /// **서로 나누어떨어지지 않게 잡는다.** 20·40초처럼 배수 관계면 40초마다
  /// 둘이 정확히 같은 자리로 돌아와 패턴이 눈에 보인다. (docs/motion.md)
  static const _periods = [Duration(seconds: 28), Duration(seconds: 34)];

  /// 원이 제자리 주위를 도는 반경 (393 폭 기준).
  ///
  /// 시안 자리에서 크게 벗어나면 화면마다 원 배치가 달라 보인다. 살아 있는
  /// 느낌만 줄 만큼 작게 둔다.
  static const _wander = 14.0;

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
          // 정지 위치가 제각각이면 화면이 어색하다. 시작점(= 시안 자리)으로 되돌린다.
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
          // 입력·보상(204)과 로딩·추가질문(244)은 두 원 자리가 40 다르다.
          // 색과 같은 곡선으로 옮겨 가 두 원이 툭 떨어지지 않는다.
          return Transform.translate(
            key: AuroraBackground.groupKey,
            offset: Offset(0, (palette.top - AuroraPalette.inputTop).h),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _blob(
                  controller: _controllers[0],
                  key: AuroraBackground.eclipseKey,
                  spec: _Blob.eclipse,
                  colors: [colors[0], colors[1]],
                ),
                _blob(
                  controller: _controllers[1],
                  key: AuroraBackground.planetKey,
                  spec: _Blob.planet,
                  colors: [colors[2], palette.planetEnd],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 원 하나. 시안 자리를 중심으로 작은 원을 그리며 돈다.
  Widget _blob({
    required AnimationController controller,
    required Key key,
    required _Blob spec,
    required List<Color> colors,
  }) {
    // 원이라 가로세로 모두 .w — .h를 섞으면 기기 비율에 따라 타원이 된다.
    final diameter = spec.diameter.w;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        // 컨트롤러가 reverse로 왕복하므로 0~1을 0~2π로 펴서 원운동을 만든다.
        // 0 에서 시작하면 제자리다 — 동작 줄이기면 여기서 멈춘다.
        final angle = controller.value * 2 * math.pi;
        final drift = Offset(
          math.sin(angle) * AuroraBackground._wander,
          (1 - math.cos(angle)) * AuroraBackground._wander,
        );
        return Positioned(
          left: (spec.left + drift.dx).w,
          top: (spec.top + drift.dy).h,
          child: child!,
        );
      },
      child: ImageFiltered(
        // 시안 레이어 블러 반경의 절반이 가우스 표준편차다 (Figma 블러 200 =
        // CSS blur(100px)). `decal` 이라 원 바깥을 투명으로 보고 번진다 —
        // 가장자리 색을 늘여 붙이면 상자 모양 띠가 생긴다.
        imageFilter: ImageFilter.blur(
          sigmaX: (spec.blur / 2).w,
          sigmaY: (spec.blur / 2).w,
          tileMode: TileMode.decal,
        ),
        child: Container(
          key: key,
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // 시안 그라데이션 손잡이가 위(0.5, 0)→아래(0.5, 1)다.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
          ),
        ),
      ),
    );
  }
}

/// 시안 `Gradient` 그룹 안 두 원의 자리 — 그룹 윗변이 204 인 입력 화면 기준.
/// 다른 화면은 그룹째 내려간다([AuroraPalette.top]).
enum _Blob {
  /// `Eclipse` (238:1729) — 356.7 원, (11.2, 225.3), 블러 200.
  eclipse(left: 11.2, top: 225.3, diameter: 356.7, blur: 200),

  /// `Planet` (238:1730) — 261 원, (120.4, 204), 블러 100.
  planet(left: 120.4, top: 204, diameter: 261, blur: 100);

  const _Blob({
    required this.left,
    required this.top,
    required this.diameter,
    required this.blur,
  });

  final double left;
  final double top;
  final double diameter;
  final double blur;
}
