import 'package:flutter/material.dart';

import '../../../../core/layout/adaptive_page_frame.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/twinkle_star_field.dart';

/// 보상·일과완료·별 화면의 밤하늘 배경 (위아래로만 변하는 그라데이션)
enum ChildNightSky {
  /// 별 모으기·카드 보상: `#0C0D1A` > `#242634`
  reward,

  /// 일과완료: `#0C0D1A` 7% 지점부터 > `#574D2B`
  routineDone,
}

/// 밤하늘 그라데이션. 화면 안과 태블릿 전폭 배경이 **같은 위젯**이라 열 바깥과 이음매 없이 이어진다
class ChildNightSkyBackdrop extends StatelessWidget {
  const ChildNightSkyBackdrop({
    super.key,
    this.sky = ChildNightSky.reward,
    this.child,
    this.hasStarField = false,
  });

  final ChildNightSky sky;

  /// 별 밭을 깔지. 태블릿 전폭 배경(라우트 backdrop)만 켠다 — 폰 화면 안 배경은 그대로
  final bool hasStarField;

  /// 별 밭 별 개수
  static const _starCount = 70;

  /// 배경 위에 얹을 화면. 없으면 배경만 꽉 채운다
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gradient = switch (sky) {
      ChildNightSky.reward => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [colors.rewardBackdropTop, colors.rewardBackdropBottom],
      ),
      ChildNightSky.routineDone => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.07, 1],
        colors: [colors.rewardBackdropTop, colors.routineDoneBackdropBottom],
      ),
    };

    // 태블릿 열 안(전폭 별 밭 위)도 별을 깐다 — 없으면 열 자리만 별이 끊겨 띠로 보인다. 폰은 그대로
    final isStarFieldVisible =
        hasStarField || AdaptivePageFrame.hasFramedBackdrop(context);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: isStarFieldVisible
          ? Stack(
              fit: StackFit.expand,
              children: [
                TwinkleStarField(
                  color: colors.nightSkyTwinkle,
                  // 열 안은 좁아 별 수를 줄이고, 바깥과 다른 자리에 뿌린다
                  starCount: hasStarField ? _starCount : _starCount ~/ 3,
                  seed: hasStarField ? 7 : 19,
                ),
                ?child,
              ],
            )
          : child ?? const SizedBox.expand(),
    );
  }
}
