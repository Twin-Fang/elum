import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 보상 화면의 빛나는 별.
///
/// Figma `Group 46`(269×269) + 주변 작은 별 2개(38 / 30).
///
/// **별은 에셋이다.** 예전에는 `Icon(Icons.star_rounded)`로 그렸는데,
/// 그것은 Material 기본 글리프라 Figma의 그라데이션 별과 모양이 다르다.
/// 게다가 위젯 테스트에서는 아이콘 폰트가 없어 **네모로 렌더**됐다
/// (골든에서 발각 — client/CLAUDE.md §2 "일러스트를 코드로 그리지 않는다").
///
/// 애니메이션은 에셋을 `Transform.scale`로 감싸 그대로 유지한다 —
/// 등장 연출 때문에 코드로 그릴 이유는 없었다.
class RewardStar extends StatefulWidget {
  const RewardStar({super.key});

  /// 큰 별이 커지는 시간. 아동 화면이라 넉넉히 둔다.
  static const popDuration = Duration(milliseconds: 700);

  /// Figma 실측 — 큰 별 209
  static const mainSize = 209.0;

  @override
  State<RewardStar> createState() => _RewardStarState();
}

class _RewardStarState extends State<RewardStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RewardStar.popDuration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 동작 줄이기를 켰으면 애니메이션 없이 최종 상태로 둔다
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    // 별은 정사각형이라 가로세로 모두 .w
    return SizedBox(
      width: RewardStar.mainSize.w,
      height: RewardStar.mainSize.w,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          // elasticOut이라 1을 넘겼다가 돌아온다 — 터지는 느낌이 난다
          final t = AppMotion.springOut.transform(_controller.value);

          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: t,
                child: _Star(
                  size: RewardStar.mainSize.w,
                  glow: colors.rewardStarGlow,
                ),
              ),
              // 작은 별들은 큰 별이 자리잡은 뒤 나타난다.
              // Figma 실측 — 초록 38(#86FCA3) · 보라 30(#A186FC)
              _Satellite(
                progress: _controller.value,
                begin: 0.5,
                offset: Offset(-88.w, 78.h),
                size: 38.w,
                asset: AppAssets.starDeco(1),
              ),
              _Satellite(
                progress: _controller.value,
                begin: 0.7,
                offset: Offset(84.w, -40.h),
                size: 30.w,
                asset: AppAssets.starDeco(7),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 큰 별. 그라데이션·글로우가 SVG 안에 들어 있다.
class _Star extends StatelessWidget {
  const _Star({required this.size, required this.glow});

  final double size;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Figma boxShadow 0 0 20 rgba(208,255,0,0.3) — 별 뒤에서 번지는 빛.
        //
        // `BoxShadow`로는 만들 수 없다. 채워진 도형 뒤에 같은 모양을 그대로
        // 칠하기 때문에 **불투명한 원판**이 깔린다(골든에서 발각).
        // 가장자리로 갈수록 투명해지는 radial gradient가 실제 글로우다.
        gradient: RadialGradient(
          colors: [glow, glow.withValues(alpha: 0)],
        ),
      ),
      // 정사각형이라 가로세로 모두 .w
      child: SvgPicture.asset(
        AppAssets.starBig,
        width: size,
        height: size,
      ),
    );
  }
}

/// 큰 별 주변의 작은 별. 색이 든 SVG를 그대로 쓴다.
class _Satellite extends StatelessWidget {
  const _Satellite({
    required this.progress,
    required this.begin,
    required this.offset,
    required this.size,
    required this.asset,
  });

  /// 전체 진행도 (0~1)
  final double progress;

  /// 이 별이 등장하기 시작하는 지점
  final double begin;

  final Offset offset;
  final double size;

  /// 별 에셋 경로. 색이 SVG 안에 들어 있어 따로 칠하지 않는다.
  final String asset;

  @override
  Widget build(BuildContext context) {
    // begin 이전에는 0, 이후 남은 구간에서 0→1
    final local = ((progress - begin) / (1 - begin)).clamp(0.0, 1.0);
    final scale = AppMotion.springOut.transform(local);

    return Transform.translate(
      offset: offset,
      child: Transform.scale(
        scale: scale,
        child: SvgPicture.asset(asset, width: size, height: size),
      ),
    );
  }
}
