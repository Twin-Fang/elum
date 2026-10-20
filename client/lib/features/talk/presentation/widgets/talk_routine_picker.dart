import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/elum_error_view.dart';
import '../../../../core/widgets/elum_state_body.dart';
import '../../../guardian/application/routine_providers.dart';
import '../../application/talk_shareable_routines_provider.dart';
import '../../domain/talk_screen_codes.dart';
import 'talk_choice_row.dart';

/// 일과 고르기: 올릴 수 있는 일과를 세로로 (제목 + 카드 수), 누르면 그 일과로 다음 단계
/// 상태: 받는 중 / 실패(다시 하기 + 에러 코드) / 없음 / 목록
class TalkRoutinePicker extends ConsumerWidget {
  const TalkRoutinePicker({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final routines = ref.watch(talkShareableRoutinesProvider);

    return switch (routines) {
      AsyncData(value: final routines) when routines.isEmpty => ElumStateBody(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: space.screenH.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.talkSharePickEmpty,
                textAlign: TextAlign.center,
                style: typo.sectionTitle.copyWith(color: colors.textPrimary),
              ),
              SizedBox(height: space.xs.h),
              Text(
                l10n.talkSharePickEmptyHint,
                textAlign: TextAlign.center,
                style: typo.body.paragraph.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
      AsyncData(value: final routines) => ListView(
        padding: EdgeInsets.symmetric(
          horizontal: space.screenH.w,
          vertical: space.sm.h,
        ),
        children: [
          Text(
            l10n.talkSharePickTitle,
            style: typo.sectionTitle.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: space.md.h),
          for (final routine in routines) ...[
            TalkChoiceRow(
              label: routine.displayTitle,
              hint: l10n.talkDetailStepCount(routine.steps.length),
              isSelected: false,
              onTap: () => onSelected(routine.id),
            ),
            SizedBox(height: space.xs.h),
          ],
        ],
      ),
      AsyncError(:final error) => ElumStateBody(
        child: ElumErrorView.failure(
          error,
          fallback: l10n.talkSharePickFailed,
          fallbackCode: TalkScreenCodes.share,
          onRetry: () => ref
            ..invalidate(routineLibraryProvider)
            ..invalidate(talkShareableRoutinesProvider),
        ),
      ),
      _ => const ElumStateBody.loading(),
    };
  }
}
