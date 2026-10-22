import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/settings_tile.dart';
import 'talk_sheet_frame.dart';

/// 글 ⋯ 메뉴에서 고른 동작
enum TalkPostMenuAction { report, block, edit, takeDown }

/// 댓글 길게 누르기 메뉴에서 고른 동작
enum TalkCommentMenuAction { report, block, delete }

/// 글 ⋯ 메뉴: 남의 글은 신고하기 · 이 보호자 글 숨기기, 내 글은 고치기 · 내리기
Future<TalkPostMenuAction?> showTalkPostMenu(
  BuildContext context, {
  required bool isMine,
}) {
  final l10n = context.l10n;
  return _showMenu<TalkPostMenuAction>(
    context,
    rows: isMine
        ? [
            _MenuItem(
              value: TalkPostMenuAction.edit,
              icon: AppAssets.iconPencil,
              label: l10n.talkMenuEdit,
            ),
            _MenuItem(
              value: TalkPostMenuAction.takeDown,
              icon: AppAssets.iconTrash,
              label: l10n.talkMenuTakeDown,
              isDanger: true,
            ),
          ]
        : [
            _MenuItem(
              value: TalkPostMenuAction.report,
              icon: AppAssets.iconFlag,
              label: l10n.talkMenuReport,
            ),
            _MenuItem(
              value: TalkPostMenuAction.block,
              icon: AppAssets.iconEyeCrossed,
              label: l10n.talkMenuBlock,
            ),
          ],
  );
}

/// 댓글 메뉴(⋯ 버튼·길게 누르기): 남의 댓글은 신고하기 · 이 보호자 글 숨기기, 내 댓글은 지우기
Future<TalkCommentMenuAction?> showTalkCommentMenu(
  BuildContext context, {
  required bool isMine,
}) {
  final l10n = context.l10n;
  return _showMenu<TalkCommentMenuAction>(
    context,
    rows: isMine
        ? [
            _MenuItem(
              value: TalkCommentMenuAction.delete,
              icon: AppAssets.iconTrash,
              label: l10n.talkCommentDeleteAction,
              isDanger: true,
            ),
          ]
        : [
            _MenuItem(
              value: TalkCommentMenuAction.report,
              icon: AppAssets.iconFlag,
              label: l10n.talkMenuReport,
            ),
            _MenuItem(
              value: TalkCommentMenuAction.block,
              icon: AppAssets.iconEyeCrossed,
              label: l10n.talkMenuBlock,
            ),
          ],
  );
}

class _MenuItem<T> {
  const _MenuItem({
    required this.value,
    required this.icon,
    required this.label,
    this.isDanger = false,
  });

  final T value;

  /// `fi-br` 아이콘 SVG 경로
  final String icon;
  final String label;

  /// 되돌리기 어려운 동작은 붉게
  final bool isDanger;
}

Future<T?> _showMenu<T>(
  BuildContext context, {
  required List<_MenuItem<T>> rows,
}) => showElumSheet<T>(
  context: context,
  builder: (sheetContext) => TalkSheetFrame(
    // 흰 묶음 판 안에 줄을 잇는다 (설정 묶음과 같은 r20 판, 줄 사이 선 없음)
    child: ClipRRect(
      borderRadius: BorderRadius.circular(context.space.cardRadius.r),
      child: ColoredBox(
        color: context.colors.settingsGroupBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in rows)
              _MenuRow(
                icon: row.icon,
                label: row.label,
                isDanger: row.isDanger,
                onTap: () => Navigator.of(sheetContext).pop(row.value),
              ),
          ],
        ),
      ),
    ),
  ),
);

/// 메뉴 한 줄 (설정 묶음 줄 결: 높이 56 · 왼쪽 20): 아이콘 20 + 글자
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.isDanger,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool isDanger;
  final VoidCallback onTap;

  static const _iconSize = 20.0;
  static const _iconToLabel = 12.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final labelColor = isDanger
        ? colors.settingsDestructive
        : colors.settingsCardLabel;
    final iconColor = isDanger
        ? colors.settingsDestructive
        : colors.talkMetaText;
    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: SettingsTile.cardHeight.h),
        child: Padding(
          padding: EdgeInsets.only(
            left: SettingsTile.cardPadLeft.w,
            right: SettingsTile.cardPadRight.w,
          ),
          child: Row(
            children: [
              SvgPicture.asset(
                icon,
                width: _iconSize.w,
                height: _iconSize.w,
                excludeFromSemantics: true,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
              SizedBox(width: _iconToLabel.w),
              Expanded(
                child: Text(
                  label,
                  style: context.typo.settingsTileLabel.copyWith(
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
