import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../../../shared/models/routine.dart';
import '../../../member/application/plan_access.dart';
import '../../../subscription/domain/plan_benefit.dart';
import '../../application/routine_schedule_controller.dart';
import 'routine_schedule_labels.dart';
import 'routine_schedule_sheet.dart';

/// 일과관리 원본 상세 시트의 반복 줄 (#782): `요일·시각 정하기` / `월·수·금 오전 8:00` / 멈춤 (+ Free 면 Pro 배지) · 누르면 반복 시트
///
/// 보상 줄과 같은 짜임 (달력 칸 40 + 카드 68). 보이는 조건은 부르는 쪽 ([canShowRoutineScheduleProvider])
class RoutineScheduleRow extends ConsumerWidget {
  const RoutineScheduleRow({super.key, required this.routine});

  final Routine routine;

  /// 줄 높이 — 보상 줄(68)과 같다
  static const rowHeight = 68.0;

  static const rowKey = ValueKey('routine.schedule.row');

  /// 왼쪽 달력 칸 폭 · 모서리 · 아이콘 한 변 · 칸 ↔ 카드 · 카드 안쪽 좌우 (알림 줄과 같은 값)
  static const _iconBoxWidth = 40.0;
  static const _iconBoxRadius = 16.0;
  static const _iconSize = 20.0;
  static const _iconToCard = 4.0;
  static const _cardPaddingH = 18.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final schedule = ref.watch(routineScheduleOfProvider(routine.id));
    final isOn = schedule != null && !schedule.isPaused;
    // Free 판매 중이면 눌러서 반복 시트의 Pro 안내로 감 (멈춘 예약도 Pro 가 있어야 다시 돎)
    final shouldShowProBadge = ref
        .watch(planAccessProvider)
        .shouldShowTeaserFor(PlanBenefit.routineSchedule);
    final label = switch (schedule) {
      null => context.l10n.routineScheduleRowOff,
      final paused when paused.isPaused => context.l10n.routineSchedulePaused,
      final active => routineScheduleSummaryLabel(context, active),
    };

    return AppPressable(
      key: rowKey,
      onTap: () => RoutineScheduleSheet.show(context, routine),
      semanticLabel: context.l10n.routineScheduleRowLabel,
      child: Row(
        children: [
          Container(
            width: _iconBoxWidth.w,
            height: rowHeight.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.editChipBg,
              borderRadius: BorderRadius.circular(_iconBoxRadius.r),
            ),
            child: SvgPicture.asset(
              AppAssets.iconCalendar,
              width: _iconSize.w,
              height: _iconSize.w,
              excludeFromSemantics: true,
              colorFilter: ColorFilter.mode(
                isOn ? colors.textPrimary : colors.rewardEmptyLabel,
                BlendMode.srcIn,
              ),
            ),
          ),
          SizedBox(width: _iconToCard.w),
          Expanded(
            child: Container(
              height: rowHeight.h,
              padding: EdgeInsets.symmetric(horizontal: _cardPaddingH.w),
              decoration: BoxDecoration(
                color: colors.editChipBg,
                borderRadius: BorderRadius.circular(space.cardRadius.r),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: LabelWithProBadge(
                      label: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typo.sheetStepTitle.copyWith(
                          color: isOn
                              ? colors.textPrimary
                              : colors.rewardEmptyLabel,
                        ),
                      ),
                      shouldShowProBadge: shouldShowProBadge,
                    ),
                  ),
                  const SettingsCardChevron(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
