import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pop_in.dart';

/// 권한 단계 진행: "권한 2/3" 글 + 차오르는 막대 (값이 바뀌면 부드럽게)
class LockScreenSetupProgress extends StatelessWidget {
  const LockScreenSetupProgress({
    super.key,
    required this.doneCount,
    required this.totalCount,
  });

  final int doneCount;
  final int totalCount;

  static const _barHeight = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final progress = totalCount == 0 ? 0.0 : doneCount / totalCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.lockScreenSetupProgress(doneCount, totalCount),
          style: context.typo.creditBody.copyWith(color: colors.textSecondary),
        ),
        SizedBox(height: space.xs.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(space.pillRadius),
          child: SizedBox(
            height: _barHeight.h,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: colors.routineRingTrack),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: progress),
                  duration: AppMotion.valueChange,
                  curve: AppMotion.decelerate,
                  builder: (context, value, _) => FractionallySizedBox(
                    widthFactor: value,
                    heightFactor: 1,
                    child: ColoredBox(color: colors.routineRingProgress),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 준비 끝: 튀어 오르는 제목 + "지금 화면을 껐다 켜 보세요"
class LockScreenSetupDoneMessage extends StatelessWidget {
  const LockScreenSetupDoneMessage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    return Padding(
      padding: EdgeInsets.only(top: space.md.h),
      child: Column(
        children: [
          AppPopIn(
            child: Text(
              context.l10n.lockScreenSetupDoneTitle,
              textAlign: TextAlign.center,
              style: context.typo.subtitle.copyWith(color: colors.textPrimary),
            ),
          ),
          SizedBox(height: space.xs.h),
          Text(
            context.l10n.lockScreenSetupDoneBody,
            textAlign: TextAlign.center,
            style: context.typo.creditBody.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
