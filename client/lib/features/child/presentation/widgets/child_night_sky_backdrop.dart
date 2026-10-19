import 'package:flutter/material.dart';

import '../../../../core/theme/theme_context_ext.dart';

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
  });

  final ChildNightSky sky;

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

    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: child ?? const SizedBox.expand(),
    );
  }
}
