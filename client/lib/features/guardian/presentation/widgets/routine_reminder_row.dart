import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../../../shared/models/routine.dart';
import '../../../reminder/application/routine_reminder_controller.dart';
import '../../../reminder/domain/routine_reminder.dart';
import 'routine_reminder_sheet.dart';

/// 일과 상세 시트의 알림 줄 (#777): 꺼짐 / `매일 오전 8:00` · 누르면 알림 설정 시트
///
/// 보상 줄과 같은 짜임 (뱃지 40 + 카드). 이 기기에만 울린다.
class RoutineReminderRow extends ConsumerWidget {
  const RoutineReminderRow({super.key, required this.routine});

  final Routine routine;

  /// 줄 높이 — 보상 줄(68)과 같다
  static const rowHeight = 68.0;

  static const rowKey = ValueKey('routine.reminder.row');

  /// 왼쪽 종 칸 폭 · 모서리 · 종 한 변 · 종 칸 ↔ 카드 · 카드 안쪽 좌우
  static const _bellBoxWidth = 40.0;
  static const _bellBoxRadius = 16.0;
  static const _bellIconSize = 20.0;
  static const _bellToCard = 4.0;
  static const _cardPaddingH = 18.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    final reminder = ref.watch(routineReminderProvider)[routine.id];
    final isOn = reminder != null;

    return AppPressable(
      key: rowKey,
      onTap: () => RoutineReminderSheet.show(context, routine),
      semanticLabel: context.l10n.reminderRowLabel,
      child: Row(
        children: [
          Container(
            width: _bellBoxWidth.w,
            height: rowHeight.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.editChipBg,
              borderRadius: BorderRadius.circular(_bellBoxRadius.r),
            ),
            // 켜짐 = 종 · 꺼짐 = 빗금 종
            child: SvgPicture.asset(
              isOn ? AppAssets.iconBell : AppAssets.iconBellSlash,
              width: _bellIconSize.w,
              height: _bellIconSize.w,
              excludeFromSemantics: true,
              colorFilter: ColorFilter.mode(
                isOn ? colors.textPrimary : colors.rewardEmptyLabel,
                BlendMode.srcIn,
              ),
            ),
          ),
          SizedBox(width: _bellToCard.w),
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
                    child: Text(
                      isOn
                          ? reminderScheduleLabel(context, reminder)
                          : context.l10n.reminderRowOff,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typo.sheetStepTitle.copyWith(
                        color: isOn
                            ? colors.textPrimary
                            : colors.rewardEmptyLabel,
                      ),
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

/// 알림 > `매일 오전 8:00` / `한 번 오전 8:00` (시각은 기기 언어 형식)
String reminderScheduleLabel(BuildContext context, RoutineReminder reminder) {
  final time = MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay(hour: reminder.hour, minute: reminder.minute));
  return reminder.isDaily
      ? context.l10n.reminderRowDaily(time)
      : context.l10n.reminderRowOnce(time);
}
