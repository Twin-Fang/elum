import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../shared/models/routine.dart';

/// 일과관리 낱개 원본을 길게 눌렀을 때 고르는 동작
enum LibraryMenuAction { send, rename, addToGroup, copy, remove }

/// 일과관리 묶음(폴더)을 길게 눌렀을 때 고르는 동작 (#807)
enum GroupMenuAction { send, rename, reorder, copy, ungroup }

/// 빠른 메뉴 한 줄: 돌려줄 값 · 아이콘 · 글자 · 붉게(되돌리기 어려운 동작)
typedef QuickMenuRow<T> = ({
  T value,
  IconData icon,
  String label,
  bool isDanger,
});

/// 낱개 원본 메뉴. 남이 만든 일과는 보내기·묶음에 넣기·복사하기만 (#805)
///
/// 이름 바꾸기·지우기는 만든 사람만 할 수 있어 서버도 막지만, 누를 수 없는 줄은 처음부터 보이지 않는다.
Future<LibraryMenuAction?> showLibraryQuickMenu(
  BuildContext context,
  Routine routine,
) {
  final l10n = context.l10n;
  final isMine = routine.isEditableByMe;
  return showQuickMenuSheet(
    context,
    title: routine.displayTitle,
    rows: [
      (
        value: LibraryMenuAction.send,
        icon: Icons.send_rounded,
        label: l10n.routineLibrarySendToday,
        isDanger: false,
      ),
      if (isMine)
        (
          value: LibraryMenuAction.rename,
          icon: Icons.edit_rounded,
          label: l10n.routineLibraryMenuRename,
          isDanger: false,
        ),
      (
        value: LibraryMenuAction.addToGroup,
        icon: Icons.create_new_folder_outlined,
        label: l10n.routineGroupMenuAddToGroup,
        isDanger: false,
      ),
      (
        value: LibraryMenuAction.copy,
        icon: Icons.content_copy_rounded,
        label: l10n.routineLibraryMenuCopy,
        isDanger: false,
      ),
      if (isMine)
        (
          value: LibraryMenuAction.remove,
          icon: Icons.delete_outline_rounded,
          label: l10n.routineLibraryMenuRemove,
          isDanger: true,
        ),
    ],
  );
}

/// 묶음 메뉴: 보내기 · 이름 바꾸기 · 순서 바꾸기 · 복사하기 · 묶음 풀기 (풀어도 일과는 남는다)
Future<GroupMenuAction?> showGroupQuickMenu(
  BuildContext context, {
  required String groupName,
}) {
  final l10n = context.l10n;
  return showQuickMenuSheet(
    context,
    title: groupName,
    rows: [
      (
        value: GroupMenuAction.send,
        icon: Icons.send_rounded,
        label: l10n.routineLibrarySendToday,
        isDanger: false,
      ),
      (
        value: GroupMenuAction.rename,
        icon: Icons.edit_rounded,
        label: l10n.routineLibraryMenuRename,
        isDanger: false,
      ),
      (
        value: GroupMenuAction.reorder,
        icon: Icons.swap_vert_rounded,
        label: l10n.routineGroupMenuReorder,
        isDanger: false,
      ),
      (
        value: GroupMenuAction.copy,
        icon: Icons.content_copy_rounded,
        label: l10n.routineLibraryMenuCopy,
        isDanger: false,
      ),
      (
        value: GroupMenuAction.ungroup,
        icon: Icons.folder_off_outlined,
        label: l10n.routineGroupMenuUngroup,
        isDanger: false,
      ),
    ],
  );
}

/// 빠른 메뉴 시트: 무엇에 대한 메뉴인지(제목) + 동작 줄. 고른 줄의 값을 돌려준다
Future<T?> showQuickMenuSheet<T>(
  BuildContext context, {
  required String title,
  required List<QuickMenuRow<T>> rows,
}) {
  return showElumSheet<T>(
    context: context,
    builder: (_) => _QuickMenuSheet<T>(title: title, rows: rows),
  );
}

class _QuickMenuSheet<T> extends StatelessWidget {
  const _QuickMenuSheet({required this.title, required this.rows});

  final String title;
  final List<QuickMenuRow<T>> rows;

  @override
  Widget build(BuildContext context) {
    final space = context.space;
    return ElumSheetSurface(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          space.md.w,
          space.lg.h,
          space.md.w,
          space.md.h + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: space.xs.w),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typo.sectionTitle.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            SizedBox(height: space.sm.h),
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
  }
}

/// 메뉴 한 줄 (아이콘 + 글자, 되돌리기 어려운 동작은 붉게)
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

  /// 아이콘 한 변 · 줄 최소 높이 (누름 영역 확보)
  static const _iconSize = 22.0;
  static const _rowMinHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final space = context.space;
    final color = isDanger ? colors.danger : colors.textPrimary;
    return AppPressable(
      onTap: onTap,
      scaleDown: AppPressable.scaleCard,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: _rowMinHeight.h),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: space.xs.w),
          child: Row(
            children: [
              Icon(icon, size: _iconSize.w, color: color),
              SizedBox(width: space.sm.w),
              Expanded(
                child: Text(
                  label,
                  style: context.typo.tileLabel.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
