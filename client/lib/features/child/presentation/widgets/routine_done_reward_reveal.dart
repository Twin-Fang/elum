import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';

/// 일과 완료 화면 보상: 선물 상자가 튀어 오르고 그 아래 "오늘의 보상"과 보상 이름
/// 시안 보상 칩(`1291:10874`) 자리에 상자 없이 그림과 글자만. 보상이 없으면 화면이 그리지 않음
class RoutineDoneRewardReveal extends StatelessWidget {
  const RoutineDoneRewardReveal({
    super.key,
    required this.rewardText,
    required this.isMotionOn,
    required this.delay,
  });

  /// 보상 이름 (이모지가 있으면 앞에 붙여서 넘김)
  final String rewardText;

  /// false 면 선물 상자 튀어 오르기 없이 정지 모양
  final bool isMotionOn;

  /// 화면 등장 순서에 맞춰 선물 상자가 튀어 오르기 전에 기다리는 시간
  final Duration delay;

  /// 선물 상자 크기 · 글자 줄 폭 (시안 칩 333 폭과 같음)
  static const _giftSize = 60.0;
  static const _textWidth = 333.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return SizedBox(
      width: _textWidth.w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GiftPop(size: _giftSize.w, isMotionOn: isMotionOn, delay: delay),
          SizedBox(height: space.xs),
          Text(
            context.l10n.routineDoneRewardCaption,
            style: context.typo.caption.copyWith(color: colors.rewardButton),
          ),
          SizedBox(height: space.xs),
          Text(
            rewardText,
            // 긴 보상은 두 줄까지 보이고 그 이상은 자른다 (명세 9-4)
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.typo.subtitle.copyWith(color: colors.surface),
          ),
        ],
      ),
    );
  }
}

/// 선물 상자: 기다린 뒤 작게 시작해 살짝 커졌다 제자리 (튀어 오르기, 700ms)
class _GiftPop extends StatelessWidget {
  const _GiftPop({
    required this.size,
    required this.isMotionOn,
    required this.delay,
  });

  final double size;
  final bool isMotionOn;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final gift = Image.asset(AppAssets.rewardGift, width: size, height: size);
    if (!isMotionOn) return gift;

    // 전체 = 지연 + 튀어 오르기(ambient). 지연 동안은 보이지 않음
    final totalDuration = delay + AppMotion.ambient;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: totalDuration,
      curve: Interval(
        delay.inMilliseconds / totalDuration.inMilliseconds,
        1,
        curve: Curves.elasticOut,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
      ),
      child: gift,
    );
  }
}
