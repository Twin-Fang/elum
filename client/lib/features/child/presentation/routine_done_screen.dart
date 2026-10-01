import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../core/assets/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/theme_context_ext.dart';
import '../../../core/widgets/elum_button.dart';

/// 이룸이가 일과를 **다 끝냈을 때** 한 번 뜨는 화면 (Figma `일과완료` 1274:9831, 이슈 #490).
///
/// 카드 하나를 끝낼 때마다 뜨는 별 화면([RewardScreen])과 다르다. 마지막 카드의 별
/// 화면을 닫으면 이어서 이 화면이 뜨고, 닫으면 이룸이 홈으로 돌아간다.
///
/// 보호자가 정한 보상은 여기서 칩으로 보여 준다. **보상이 없으면 칩을 그리지 않는다** —
/// 제목과 버튼 자리는 시안 좌표에 고정이라 칩이 빠져도 나머지는 움직이지 않는다.
class RoutineDoneScreen extends StatelessWidget {
  const RoutineDoneScreen({super.key, this.reward});

  /// 보호자가 정한 보상. 비면 칩을 그리지 않는다.
  final ({String emoji, String text})? reward;

  /// 시안 프레임에서 안전영역 윗변(상태바 아래)의 y. 시안 좌표에서 이 값을 빼서 놓는다.
  static const _safeTop = 59.0;

  /// 시안 프레임 좌표(x, y) → 안전영역 안 좌표. 그림은 가로세로를 같이 줄이려 `.w`로 통일한다.
  static double _x(double v) => v.w;
  static double _y(double v) => (v - _safeTop).w;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    final colors = context.colors;
    final reward = this.reward;

    return Scaffold(
      body: DecoratedBox(
        // Figma linear-gradient(180deg, #0C0D1A 7% → #39514D 100%)
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.07, 1],
            colors: [
              colors.rewardBackdropTop,
              colors.routineDoneBackdropBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 장식 — 별 다섯 개와 루미. 시안 절대좌표 그대로다.
              const _Decoration(),
              Column(
                children: [
                  // **`Spacer`가 아니다.** 남는 자리를 나누면 화면 높이에 따라 글자가
                  // 오르내려 시안과 어긋난다 (보상 화면과 같은 이유).
                  SizedBox(height: _y(420)),
                  _FadeIn(
                    delay: AppMotion.normal,
                    child: Text(
                      '일과를 끝냈어요!',
                      style: context.typo.cardHeadline.copyWith(
                        color: colors.surface,
                      ),
                    ),
                  ),
                  if (reward != null) ...[
                    // 제목(y420, 높이 30) → 칩(y481)
                    SizedBox(height: 31.h),
                    _FadeIn(
                      delay: AppMotion.slow,
                      child: _RewardChip(
                        text: reward.emoji.isEmpty
                            ? reward.text
                            : '${reward.emoji} ${reward.text}',
                      ),
                    ),
                  ],
                  const Spacer(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      space.buttonMarginH,
                      0,
                      space.buttonMarginH,
                      // 버튼이 y675~741 이고 홈 인디케이터 21 을 빼면 90 이 남는다 (보상 화면과 같다).
                      90.h,
                    ),
                    child: _FadeIn(
                      delay: AppMotion.slow,
                      child: ElumButton(
                        label: '오예!',
                        backgroundColor: colors.rewardButton,
                        labelColor: colors.textPrimary,
                        // 일과를 다 끝냈으니 상세로 돌아갈 곳이 없다 — 홈으로 간다.
                        onPressed: () => context.go(Routes.child),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 별 다섯 개와 루미 (시안 `1274:10258`~`10264`).
///
/// 모두 후광·투명도가 구워진 PNG라 코드에서 효과를 또 주지 않는다. 그림 크기는
/// 후광을 포함한 에셋 크기이고, 자리는 시안 상자의 **중심**에 맞춘다.
class _Decoration extends StatelessWidget {
  const _Decoration();

  /// 별: (에셋, 시안 상자 중심 x, y, 에셋 가로, 세로 — 3배 export 를 3으로 나눈 값).
  /// 중심은 시안 export 와 맞댄 뒤 1~2px 보정한 값이다(별이 기울어 상자 중심과 그림 중심이 다르다).
  static const _stars = <(String, double, double, double, double)>[
    (AppAssets.routineDoneStarGreen, 341.04, 130.08, 56.33, 54.67),
    (AppAssets.routineDoneStarOrange, 63.76, 230.20, 60.67, 60.67),
    (AppAssets.routineDoneStarRed, 238.55, 153.55, 44.67, 45.33),
    (AppAssets.routineDoneStarPink, 123.19, 127.19, 38.67, 38.67),
    (AppAssets.routineDoneStarPurple, 301.21, 248.21, 38.67, 38.67),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final (asset, cx, cy, w, h) in _stars)
          Positioned(
            left: RoutineDoneScreen._x(cx - w / 2),
            top: RoutineDoneScreen._y(cy - h / 2),
            child: ExcludeSemantics(
              child: Image.asset(asset, width: w.w, height: h.w),
            ),
          ),
        // 루미 — 시안 `Group 66`(116.55, 195). 내보낸 그림은 그룹 상자보다 안쪽이라
        // 시안 그림과 겹치도록 (+4, +3) 옮겨 놓는다 (시안 export 와 맞댄 값). 눈웃음은 따로 얹는다.
        Positioned(
          left: RoutineDoneScreen._x(120.55),
          top: RoutineDoneScreen._y(198),
          child: ExcludeSemantics(
            child: Image.asset(
              AppAssets.routineDoneLumi,
              width: 144.33.w,
              height: 157.33.w,
            ),
          ),
        ),
        Positioned(
          left: RoutineDoneScreen._x(205.5),
          top: RoutineDoneScreen._y(265.5),
          child: ExcludeSemantics(
            child: SvgPicture.asset(
              AppAssets.routineDoneWink,
              width: 11.w,
              height: 6.w,
            ),
          ),
        ),
      ],
    );
  }
}

/// 보상 칩 (시안 `1274:9858` — 333×80, 모서리 20, `#EEE9E6` 30%, 글자 18/800 흰색).
///
/// 카드별 별 화면의 [RewardBanner]와 모양이 다르다(높이 48·모서리 8·`다하면` 문구).
/// 이 화면의 칩은 이미 다 했으니 **보상 문구만** 보여 준다.
class _RewardChip extends StatelessWidget {
  const _RewardChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 333.w,
      height: 80.h,
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.routineTileBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        text,
        // 긴 보상은 두 줄까지 보이고 그 이상은 자른다 (명세 9-4).
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: context.typo.childTileTitle.copyWith(color: colors.surface),
      ),
    );
  }
}

/// 지연 후 나타나며 살짝 올라온다. 동작 줄이기를 켰으면 바로 보여 준다.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.slow,
      curve: Interval(
        (delay.inMilliseconds / (AppMotion.slow.inMilliseconds * 2)).clamp(
          0.0,
          0.9,
        ),
        1,
        curve: AppMotion.entry,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 16),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
