import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../application/home_routines.dart';

/// 보호자 홈 `오늘 일과` 제목 오른쪽 이룸이 진행 칩: 체크 + `이룸이 오늘 2/5` > 누르면 이룸이 화면 (#1455)
/// 오늘 일과가 없으면 자리 없음. 큰 글자에서는 줄어들어 한 줄 유지
class ElumiTodayProgressPill extends ConsumerWidget {
  const ElumiTodayProgressPill({super.key});

  /// 체크 그림 · 안쪽 여백 · 그림 > 글
  static const _checkIconSize = 14.0;
  static const _horizontalPadding = 10.0;
  static const _verticalPadding = 6.0;
  static const _iconToText = 4.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayProgress = ref.watch(elumiTodayProgressProvider);
    if (todayProgress.totalRoutineCount == 0) return const SizedBox.shrink();
    final colors = context.colors;
    final l10n = context.l10n;
    final isAllFinished = todayProgress.finishedRoutineCount == todayProgress.totalRoutineCount;
    return AppPressable(
      onTap: () => context.go(Routes.child),
      scaleDown: AppPressable.scaleIcon,
      semanticLabel: l10n.guardianHomeElumiTodayProgressSemantics(
        todayProgress.finishedRoutineCount,
        todayProgress.totalRoutineCount,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: _horizontalPadding.w, vertical: _verticalPadding.h),
        decoration: BoxDecoration(
          color: isAllFinished ? colors.routineRingProgress : colors.surface,
          borderRadius: BorderRadius.circular(context.space.pillRadius),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                AppAssets.iconCheck,
                width: _checkIconSize.w,
                height: _checkIconSize.w,
                colorFilter: ColorFilter.mode(
                  isAllFinished ? colors.surface : colors.routineRingProgress,
                  BlendMode.srcIn,
                ),
              ),
              SizedBox(width: _iconToText.w),
              Text(
                l10n.guardianHomeElumiTodayProgress(
                  todayProgress.finishedRoutineCount,
                  todayProgress.totalRoutineCount,
                ),
                maxLines: 1,
                style: context.typo.creditBody.copyWith(
                  color: isAllFinished ? colors.surface : colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
