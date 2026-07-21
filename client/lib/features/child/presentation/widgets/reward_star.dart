import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 보상 화면의 빛나는 별.
///
/// Figma는 별 5개를 겹쳐 뒀다 — 큰 별 3겹(blur 20 / glow / inset)과 주변의
/// 작은 별 2개. 코드로 그리는 이유는 **터지는 애니메이션이 필요해서**다.
/// 정적 SVG로는 등장 연출을 만들 수 없다.
///
/// 큰 별은 튕기며 커지고, 작은 별들은 뒤따라 나타난다.
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
                  color: colors.rewardStar,
                  glow: colors.rewardStarGlow,
                ),
              ),
              // 작은 별들은 큰 별이 자리잡은 뒤 나타난다
              _Satellite(
                progress: _controller.value,
                begin: 0.5,
                offset: Offset(-88.w, 78.h),
                size: 38.w,
                color: colors.rewardStarGreen,
              ),
              _Satellite(
                progress: _controller.value,
                begin: 0.7,
                offset: Offset(84.w, -40.h),
                size: 30.w,
                color: colors.rewardStarPurple,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 큰 별을 둘러싼 빛까지 함께 그린다.
class _Star extends StatelessWidget {
  const _Star({required this.size, required this.color, required this.glow});

  final double size;
  final Color color;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Figma boxShadow 0 0 20 rgba(208,255,0,0.3)
        boxShadow: [
          BoxShadow(color: glow, blurRadius: 40.w, spreadRadius: 10.w),
        ],
      ),
      child: Icon(Icons.star_rounded, size: size, color: color),
    );
  }
}

/// 큰 별 주변의 작은 별.
class _Satellite extends StatelessWidget {
  const _Satellite({
    required this.progress,
    required this.begin,
    required this.offset,
    required this.size,
    required this.color,
  });

  /// 전체 진행도 (0~1)
  final double progress;

  /// 이 별이 등장하기 시작하는 지점
  final double begin;

  final Offset offset;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // begin 이전에는 0, 이후 남은 구간에서 0→1
    final local = ((progress - begin) / (1 - begin)).clamp(0.0, 1.0);
    final scale = AppMotion.springOut.transform(local);

    return Transform.translate(
      offset: offset,
      child: Transform.scale(
        scale: scale,
        child: Icon(Icons.star_rounded, size: size, color: color),
      ),
    );
  }
}
