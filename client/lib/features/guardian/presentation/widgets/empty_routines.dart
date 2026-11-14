import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_empty_state.dart';
import '../../application/home_next_step.dart';

/// 보호자 홈 오늘 일과 0건: 2가지
/// - 「다음에 할 일」 카드가 보이면 회색 한 줄만 (같은 권유를 두 번 보이지 않음)
/// - 아니면 3D 그림 + `오늘 보낸 일과가 없어요` + 일과관리로 가기 (만들어 둔 일과를 바로 보냄)
class EmptyRoutines extends ConsumerWidget {
  const EmptyRoutines({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final isNextStepShown = ref.watch(homeNextStepProvider) != HomeNextStep.none;
    if (isNextStepShown) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          l10n.todayRoutineEmptyNotSent,
          style: context.typo.routineEmptyPast.copyWith(color: context.colors.routineTileLabel),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.space.sm.h),
      child: Center(
        child: ElumEmptyState(
          size: ElumEmptyStateSize.inline,
          illustrationAsset: AppAssets.emptyStateNoRoutines,
          title: l10n.todayRoutineEmptyTodayTitle,
          body: l10n.todayRoutineEmptyTodayBody,
          actionLabel: l10n.weeklyReportGoToManage,
          onAction: () => context.go(Routes.guardianManage),
        ),
      ),
    );
  }
}
