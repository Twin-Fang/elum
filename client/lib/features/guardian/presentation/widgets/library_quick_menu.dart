import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../shared/models/routine.dart';

/// 일과관리 칸을 길게 눌렀을 때 고르는 동작 4개
enum LibraryMenuAction { send, rename, copy, remove }

/// 빠른 메뉴 시트: 제목 + 동작 줄. 남이 만든 일과는 보내기·복사하기만 (#805)
///
/// 이름 바꾸기·지우기는 만든 사람만 할 수 있어 서버도 막지만, 누를 수 없는 줄은 처음부터 보이지 않는다.
Future<LibraryMenuAction?> showLibraryQuickMenu(
  BuildContext context,
  Routine routine,
) {
  return showElumSheet<LibraryMenuAction>(
    context: context,
    builder: (_) => _LibraryQuickMenu(routine: routine),
  );
}

class _LibraryQuickMenu extends StatelessWidget {
  const _LibraryQuickMenu({required this.routine});

  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final space = context.space;
    final isMine = routine.isEditableByMe;
    final rows = <(LibraryMenuAction, IconData, String, bool)>[
      (
        LibraryMenuAction.send,
        Icons.send_rounded,
        l10n.routineLibrarySendToday,
        false,
      ),
      if (isMine)
        (
          LibraryMenuAction.rename,
          Icons.edit_rounded,
          l10n.routineLibraryMenuRename,
          false,
        ),
      (
        LibraryMenuAction.copy,
        Icons.content_copy_rounded,
        l10n.routineLibraryMenuCopy,
        false,
      ),
      if (isMine)
        (
          LibraryMenuAction.remove,
          Icons.delete_outline_rounded,
          l10n.routineLibraryMenuRemove,
          true,
        ),
    ];

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
            // 무엇에 대한 메뉴인지
            Padding(
              padding: EdgeInsets.symmetric(horizontal: space.xs.w),
              child: Text(
                routine.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typo.sectionTitle.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            SizedBox(height: space.sm.h),
            for (final (action, icon, label, isDanger) in rows)
              _MenuRow(
                icon: icon,
                label: label,
                isDanger: isDanger,
                onTap: () => Navigator.of(context).pop(action),
              ),
          ],
        ),
      ),
    );
  }
}

/// 메뉴 한 줄 (아이콘 + 글자, 지우기는 붉게)
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
