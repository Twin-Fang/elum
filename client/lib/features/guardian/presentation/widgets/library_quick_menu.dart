import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../../../core/widgets/app_pressable.dart';
import '../../../../core/widgets/elum_bottom_sheet.dart';
import '../../../../core/widgets/elum_sheet_frame.dart';
import '../../../../core/widgets/settings_tile.dart';
import '../../../../shared/models/routine.dart';
import 'anchored_quick_menu.dart';

/// 일과관리 낱개 원본을 길게 눌렀을 때 고르는 동작
enum LibraryMenuAction { send, rename, addToGroup, copy, shareToTalk, remove }

/// 일과관리 묶음(폴더)을 길게 눌렀을 때 고르는 동작 (#807)
enum GroupMenuAction { send, rename, reorder, copy, ungroup }

/// 낱개 원본 메뉴. 남이 만든 일과는 보내기·묶음에 넣기·복사하기만 (#805)
///
/// 이름 바꾸기·지우기는 만든 사람만 할 수 있어 서버도 막지만, 누를 수 없는 줄은 처음부터 보이지 않는다.
/// [sharedPostIdBySourceRoutineId] 는 이야기에 올린 글(원본 일과 id > 글 id), 올린 일과면 `내 글 보기` 줄이 된다.
Future<LibraryMenuAction?> showLibraryQuickMenu(
  BuildContext context,
  Routine routine, {
  required Rect anchor,
  required Widget highlight,
  Map<String, String> sharedPostIdBySourceRoutineId = const {},
}) => showAnchoredQuickMenu(
  context,
  anchor: anchor,
  highlight: highlight,
  rows: libraryMenuRows(
    context,
    routine,
    sharedPostIdBySourceRoutineId: sharedPostIdBySourceRoutineId,
  ),
);

/// 같은 메뉴를 아래 시트로: 상세 시트의 ⋯ 처럼 눌린 칸이 없을 때 (#834)
Future<LibraryMenuAction?> showLibraryQuickMenuSheet(
  BuildContext context,
  Routine routine, {
  Map<String, String> sharedPostIdBySourceRoutineId = const {},
}) => showQuickMenuSheet(
  context,
  title: routine.displayTitle,
  rows: libraryMenuRows(
    context,
    routine,
    sharedPostIdBySourceRoutineId: sharedPostIdBySourceRoutineId,
  ),
);

/// 낱개 원본 메뉴 줄 (격자가 길게 누르는 동안 그리는 미리보기도 이 줄을 쓴다)
List<QuickMenuRow<LibraryMenuAction>> libraryMenuRows(
  BuildContext context,
  Routine routine, {
  Map<String, String> sharedPostIdBySourceRoutineId = const {},
}) {
  final l10n = context.l10n;
  final isMine = routine.isEditableByMe;
  // 예시 일과 · 이야기에서 가져온 일과는 올릴 수 없다
  final canShareToTalk = !routine.isExample && routine.talkPostId == null;
  final hasSharedPost = sharedPostIdBySourceRoutineId.containsKey(routine.id);
  return [
    (
      value: LibraryMenuAction.send,
      icon: AppAssets.iconPaperPlane,
      label: l10n.routineLibrarySendToday,
      isDanger: false,
    ),
    if (isMine)
      (
        value: LibraryMenuAction.rename,
        icon: AppAssets.iconPencil,
        label: l10n.routineLibraryMenuRename,
        isDanger: false,
      ),
    (
      value: LibraryMenuAction.addToGroup,
      icon: AppAssets.iconFolderAdd,
      label: l10n.routineGroupMenuAddToGroup,
      isDanger: false,
    ),
    (
      value: LibraryMenuAction.copy,
      icon: AppAssets.iconCopy,
      label: l10n.routineLibraryMenuCopy,
      isDanger: false,
    ),
    if (canShareToTalk)
      (
        value: LibraryMenuAction.shareToTalk,
        icon: AppAssets.iconBook,
        label: hasSharedPost ? l10n.talkMenuViewMyPost : l10n.talkMenuShare,
        isDanger: false,
      ),
    if (isMine)
      (
        value: LibraryMenuAction.remove,
        icon: AppAssets.iconTrash,
        label: l10n.routineLibraryMenuRemove,
        isDanger: true,
      ),
  ];
}

/// 묶음 메뉴: 보내기 · 이름 바꾸기 · 순서 바꾸기 · 복사하기 · 묶음 풀기 (풀어도 일과는 남는다)
Future<GroupMenuAction?> showGroupQuickMenu(
  BuildContext context, {
  required Rect anchor,
  required Widget highlight,
}) => showAnchoredQuickMenu(
  context,
  anchor: anchor,
  highlight: highlight,
  rows: groupMenuRows(context),
);

/// 묶음 메뉴 줄 (격자 미리보기도 이 줄을 쓴다)
List<QuickMenuRow<GroupMenuAction>> groupMenuRows(BuildContext context) {
  final l10n = context.l10n;
  return [
    (
      value: GroupMenuAction.send,
      icon: AppAssets.iconPaperPlane,
      label: l10n.routineLibrarySendToday,
      isDanger: false,
    ),
    (
      value: GroupMenuAction.rename,
      icon: AppAssets.iconPencil,
      label: l10n.routineLibraryMenuRename,
      isDanger: false,
    ),
    (
      value: GroupMenuAction.reorder,
      icon: AppAssets.iconInterlining,
      label: l10n.routineGroupMenuReorder,
      isDanger: false,
    ),
    (
      value: GroupMenuAction.copy,
      icon: AppAssets.iconCopy,
      label: l10n.routineLibraryMenuCopy,
      isDanger: false,
    ),
    (
      value: GroupMenuAction.ungroup,
      icon: AppAssets.iconFolderMinus,
      label: l10n.routineGroupMenuUngroup,
      isDanger: false,
    ),
  ];
}

/// 빠른 메뉴 시트 (이야기 ⋯ 메뉴와 같은 결): 제목 > 흰 묶음 판 안 줄 56. 고른 줄의 값을 돌려준다
Future<T?> showQuickMenuSheet<T>(
  BuildContext context, {
  required String title,
  required List<QuickMenuRow<T>> rows,
}) {
  return showElumSheet<T>(
    context: context,
    builder: (_) => ElumSheetFrame(
      title: title,
      child: QuickMenuGroup<T>(rows: rows),
    ),
  );
}

/// 흰 묶음 판(r20, 줄 사이 선 없음) 안 메뉴 줄들. 누르면 그 줄의 값으로 시트를 닫는다
class QuickMenuGroup<T> extends StatelessWidget {
  const QuickMenuGroup({super.key, required this.rows});

  final List<QuickMenuRow<T>> rows;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
                onTap: () => Navigator.of(context).pop(row.value),
              ),
          ],
        ),
      ),
    );
  }
}

/// 메뉴 한 줄 (설정 묶음 줄 결: 높이 56 · 왼쪽 20): 아이콘 20 + 글자, 되돌리기 어려운 동작은 붉게
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.isDanger,
    required this.onTap,
  });

  /// `fi-br` 아이콘 SVG 경로
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
        : colors.settingsGroupLabel;
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
