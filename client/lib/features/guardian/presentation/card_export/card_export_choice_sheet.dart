import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_check_circle.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../../../core/widgets/settings_group.dart';

/// 고르기 시트의 한 줄: 값 · 이름 · (설명) · Pro 잠금
@immutable
class CardExportChoice<T> {
  const CardExportChoice({required this.value, required this.label, this.caption, this.isLocked = false});

  final T value;
  final String label;
  final String? caption;

  /// Free 라 못 고르는 값 (Pro 배지, 눌러도 값을 돌려줌 > 부르는 쪽이 Pro 미리 보기)
  final bool isLocked;
}

/// 인쇄용으로 받기 고르기 시트: 제목 > 줄 목록 (고른 줄에 체크) > 누른 값을 돌려줌, 닫으면 null
Future<T?> showCardExportChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required List<CardExportChoice<T>> choices,
  required T selected,
}) {
  return showElumSheet<T>(
    context: context,
    builder: (sheetContext) => ElumSheetFrame(
      title: title,
      child: SettingsGroup(
        children: [
          for (final choice in choices)
            _ChoiceRow<T>(
              choice: choice,
              isSelected: choice.value == selected,
              onTap: () => Navigator.of(sheetContext).pop(choice.value),
            ),
        ],
      ),
    ),
  );
}

/// 한 줄: 이름(+Pro 배지) · 설명 · 고른 표시
class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({required this.choice, required this.isSelected, required this.onTap});

  final CardExportChoice<T> choice;
  final bool isSelected;
  final VoidCallback onTap;

  /// 줄 안쪽 여백 (설정 묶음 줄과 같은 좌우)
  static const _padLeft = 20.0;
  static const _padRight = 16.0;
  static const _padVertical = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final caption = choice.caption;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: isSelected,
      child: AppPressable(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(_padLeft.w, _padVertical.h, _padRight.w, _padVertical.h),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LabelWithProBadge(
                      label: Text(
                        choice.label,
                        style: context.typo.settingsTileLabel.copyWith(color: colors.settingsCardLabel),
                      ),
                      shouldShowProBadge: choice.isLocked,
                    ),
                    if (caption != null) ...[
                      SizedBox(height: 4.h),
                      Text(caption, style: context.typo.caption.copyWith(color: colors.textSecondary)),
                    ],
                  ],
                ),
              ),
              ElumCheckCircle(isChecked: isSelected),
            ],
          ),
        ),
      ),
    );
  }
}
