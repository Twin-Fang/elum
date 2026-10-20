import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
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
              icon: Icons.edit_rounded,
              label: l10n.talkMenuEdit,
            ),
            _MenuItem(
              value: TalkPostMenuAction.takeDown,
              icon: Icons.delete_outline_rounded,
              label: l10n.talkMenuTakeDown,
              isDanger: true,
            ),
          ]
        : [
            _MenuItem(
              value: TalkPostMenuAction.report,
              icon: Icons.flag_outlined,
              label: l10n.talkMenuReport,
            ),
            _MenuItem(
              value: TalkPostMenuAction.block,
              icon: Icons.visibility_off_outlined,
              label: l10n.talkMenuBlock,
            ),
          ],
  );
}

/// 댓글 메뉴: 남의 댓글은 신고하기 · 이 보호자 글 숨기기, 내 댓글은 지우기
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
              icon: Icons.delete_outline_rounded,
              label: l10n.talkCommentDeleteAction,
              isDanger: true,
            ),
          ]
        : [
            _MenuItem(
              value: TalkCommentMenuAction.report,
              icon: Icons.flag_outlined,
              label: l10n.talkMenuReport,
            ),
            _MenuItem(
              value: TalkCommentMenuAction.block,
              icon: Icons.visibility_off_outlined,
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
  final IconData icon;
  final String label;

  /// 되돌리기 어려운 동작은 붉게
  final bool isDanger;
}

Future<T?> _showMenu<T>(
  BuildContext context, {
  required List<_MenuItem<T>> rows,
}) => showElumSheet<T>(
  context: context,
  builder: (_) => TalkSheetFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          _MenuRow(
            icon: row.icon,
            label: row.label,
            isDanger: row.isDanger,
            onTap: () => Navigator.of(context).pop(row.value),
          ),
      ],
    ),
  ),
);

/// 메뉴 한 줄 (아이콘 + 글자)
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.isDanger,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDanger;
  final VoidCallback onTap;

  static const _iconSize = 22.0;
  static const _rowMinHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = isDanger ? colors.danger : colors.textPrimary;
    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: _rowMinHeight.h),
        child: Row(
          children: [
            Icon(icon, size: _iconSize.w, color: color),
            SizedBox(width: context.space.sm.w),
            Expanded(
              child: Text(
                label,
                style: context.typo.tileLabel.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
