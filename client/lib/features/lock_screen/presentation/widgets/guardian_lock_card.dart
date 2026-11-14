import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/lock_screen/lock_screen_snapshot.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pop_in.dart';
import '../../../../core/text/keep_words.dart';

/// 보호자 잠금화면 카드 본문: 3D 그림 > "오늘 이룸이 일과" > 큰 2/3 > 진행 칸 > 다음 할 일
/// 요약이 없거나 어제 것이면 "앱을 열어 오늘 일과를 확인해요" 한 줄 (잠금화면은 네트워크를 쓰지 않음)
class GuardianLockCard extends StatelessWidget {
  const GuardianLockCard({super.key, required this.snapshot, required this.now});

  final LockScreenSnapshot? snapshot;
  final DateTime now;

  static const _artSize = 120.0;

  /// 진행 칸: 높이 10, 칸 사이 6, 최대 칸 수 (넘으면 한 줄 막대 하나로)
  static const _segmentHeight = 10.0;
  static const _segmentGap = 6.0;
  static const _maximumSegmentCount = 8;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final snapshot = this.snapshot;
    final isFresh = snapshot != null && snapshot.isFreshOn(now);
    final hasRoutines = isFresh && snapshot.totalCount > 0;
    final illustration = !hasRoutines
        ? AppAssets.emptyStateNoRoutines
        : snapshot.isAllDone
        ? AppAssets.celebrationElumiCompleted
        : AppAssets.featureIconLockScreen;
    final message = !isFresh
        ? context.l10n.lockScreenStaleMessage
        : !hasRoutines
        ? context.l10n.lockScreenGuardianNoRoutine
        : snapshot.isAllDone
        ? context.l10n.lockScreenGuardianAllDone
        : snapshot.nextRoutineTitle == null
        ? null
        : context.l10n.lockScreenGuardianNext(snapshot.nextRoutineTitle!);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppPopIn(
          child: Image.asset(
            illustration,
            width: _artSize.w,
            height: _artSize.w,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
        ),
        SizedBox(height: space.md.h),
        Text(
          context.l10n.lockScreenGuardianTitle,
          textAlign: TextAlign.center,
          style: typo.subtitle.copyWith(color: colors.textSecondary),
        ),
        if (hasRoutines) ...[
          SizedBox(height: space.xs.h),
          Text(
            context.l10n.lockScreenGuardianCount(
              snapshot.doneCount,
              snapshot.totalCount,
            ),
            textAlign: TextAlign.center,
            style: typo.cardHeadline.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: space.sm.h),
          _progressSegments(context, snapshot),
        ],
        if (message != null) ...[
          SizedBox(height: space.md.h),
          Text(
            keepWords(message, locale: context.appLocale),
            semanticsLabel: message,
            textAlign: TextAlign.center,
            style: typo.cardDescription.copyWith(color: colors.textPrimary),
          ),
        ],
      ],
    );
  }

  /// 일과 수만큼 칸 (끝낸 칸은 민트). 너무 많으면 한 줄 막대로 비율만
  Widget _progressSegments(BuildContext context, LockScreenSnapshot snapshot) {
    final colors = context.colors;
    final segmentCount = snapshot.totalCount > _maximumSegmentCount
        ? 1
        : snapshot.totalCount;
    final radius = BorderRadius.circular(context.space.pillRadius);
    if (segmentCount == 1 && snapshot.totalCount > 1) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: _segmentHeight.h,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: colors.routineRingTrack)),
              FractionallySizedBox(
                widthFactor: snapshot.doneCount / snapshot.totalCount,
                child: ColoredBox(color: colors.routineRingProgress),
              ),
            ],
          ),
        ),
      );
    }
    return Row(
      children: [
        for (var index = 0; index < segmentCount; index++) ...[
          if (index > 0) SizedBox(width: _segmentGap.w),
          Expanded(
            child: Container(
              height: _segmentHeight.h,
              decoration: BoxDecoration(
                borderRadius: radius,
                color: index < snapshot.doneCount
                    ? colors.routineRingProgress
                    : colors.routineRingTrack,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
