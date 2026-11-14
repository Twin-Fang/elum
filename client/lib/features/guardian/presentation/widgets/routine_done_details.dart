import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/content_locale.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_count_up.dart';
import '../../../../core/widgets/app_reveal.dart';
import '../../application/routine_done_summary.dart';

/// 끝낸 일과 축하 아래: 별 그림 + `별 N개` (0에서 셈) > 끝낸 일과 이름 (최대 3개, 넘으면 `외 N개`)
/// 축하 연출(그림 > 글)이 끝날 즈음 떠오름
class RoutineDoneDetails extends StatelessWidget {
  const RoutineDoneDetails({super.key, required this.summary});

  final RoutineDoneSummary summary;

  /// 이름을 보이는 일과 수 (넘으면 `외 N개`)
  static const _maxTitleCount = 3;

  /// 별 그림 크기
  static const _starSize = 40.0;

  /// 축하 장면 글이 다 올라온 뒤 시작 (AppCelebration 이유 줄 끝 0.58 지점)
  static final _revealDelay = AppMotion.emphasis * 2;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;
    final colors = context.colors;
    final routines = summary.finishedRoutines;
    final shownRoutines = routines.take(_maxTitleCount).toList();
    final hiddenCount = routines.length - shownRoutines.length;
    return AppReveal(
      delay: _revealDelay,
      child: Padding(
        padding: EdgeInsets.only(top: space.md.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 별 그림 + 세며 올라가는 별 수
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  AppAssets.featureIconStar,
                  width: _starSize.w,
                  height: _starSize.w,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
                SizedBox(width: space.xs.w),
                AppCountUp(
                  from: 0,
                  to: summary.starCount,
                  delay: _revealDelay,
                  format: l10n.routineDoneStars,
                  style: context.typo.subtitle.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
            SizedBox(height: space.xs.h),
            // 끝낸 일과 이름: 일과 언어로
            for (final routine in shownRoutines)
              ContentLocale(
                language: routine.language,
                child: Text(
                  routine.displayTitle,
                  textAlign: TextAlign.center,
                  style: context.typo.creditBody.copyWith(color: colors.textSecondary),
                ),
              ),
            if (hiddenCount > 0)
              Text(
                l10n.routineDoneMoreRoutines(hiddenCount),
                textAlign: TextAlign.center,
                style: context.typo.creditBody.copyWith(color: colors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
