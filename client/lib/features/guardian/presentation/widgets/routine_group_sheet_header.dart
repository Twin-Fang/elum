import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../domain/routine_group.dart';

/// 묶음 시트 머리 (시트 제목 결 1759:9649): 이름 700/20 왼쪽 x=24(그 자리에서 고침) · 편집/완료 · ✕ > 일과 N개
class RoutineGroupSheetHeader extends StatelessWidget {
  const RoutineGroupSheetHeader({
    super.key,
    required this.nameController,
    required this.nameFocus,
    required this.routineCount,
    required this.isEditing,
    required this.onEditToggle,
  });

  final TextEditingController nameController;
  final FocusNode nameFocus;
  final int routineCount;

  /// 순서 편집 중이면 `완료`, 아니면 `편집`
  final bool isEditing;

  /// null 이면 저장 중이라 누를 수 없다
  final VoidCallback? onEditToggle;

  /// 제목이 본문보다 더 들어가는 폭 (24 - 16) · 제목 > 개수 · ✕ 한 변
  static const _textInset = 8.0;
  static const _titleToCount = 4.0;
  static const _closeIconSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final typo = context.typo;
    final space = context.space;
    return Padding(
      padding: EdgeInsets.only(left: _textInset.w),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이름 > 일과 N개
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  focusNode: nameFocus,
                  maxLength: RoutineGroup.nameMaxLength,
                  maxLines: 1,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => nameFocus.unfocus(),
                  style: typo.sheetTitle.copyWith(color: colors.sheetTitleText),
                  decoration: InputDecoration.collapsed(
                    hintText: l10n.routineGroupNameHint,
                    hintStyle: typo.sheetTitle.copyWith(
                      color: colors.textPlaceholder,
                    ),
                  ).copyWith(counterText: ''),
                ),
                SizedBox(height: _titleToCount.h),
                Text(
                  l10n.routineGroupSheetCount(routineCount),
                  style: typo.routineTileMeta.copyWith(
                    color: colors.settingsGroupLabel,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: space.xs.w),
          // 편집 / 완료
          AppPressable(
            onTap: onEditToggle,
            scaleDown: AppPressable.scaleIcon,
            child: Padding(
              padding: EdgeInsets.all(space.xs.w),
              child: Text(
                isEditing
                    ? l10n.libraryArrangeDone
                    : l10n.routineGroupEditOrder,
                style: typo.settingsTileLabel.copyWith(
                  color: colors.settingsGroupLabel,
                ),
              ),
            ),
          ),
          // ✕ 닫기
          AppPressable(
            onTap: () => Navigator.of(context).pop(),
            scaleDown: AppPressable.scaleIcon,
            semanticLabel: l10n.commonClose,
            child: Padding(
              padding: EdgeInsets.all(space.xs.w),
              child: SvgPicture.asset(
                AppAssets.iconClose,
                width: _closeIconSize.w,
                height: _closeIconSize.w,
                excludeFromSemantics: true,
                colorFilter: ColorFilter.mode(
                  colors.settingsGroupLabel,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
